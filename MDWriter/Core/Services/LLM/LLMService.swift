//
//  LLMService.swift
//  MDWriter
//

import Foundation
import SwiftData
import SwiftUI

/// Main orchestrator service for local LLM chat, streaming completions, and Tool Calling loop.
@Observable
@MainActor
final class LLMService {
    // MARK: - State

    var isProcessing: Bool = false
    var currentStreamingText: String = ""
    var errorMessage: String? = nil
    var availableModels: [LLMModel] = []

    let config = LLMConfiguration()
    private let client = OpenAIClient()
    private var currentTask: Task<Void, Never>? = nil

    // MARK: - Models Fetching

    func fetchAvailableModels() async {
        guard config.isLLMEnabled else { return }
        do {
            let models = try await client.listModels(baseURL: config.baseURL)
            self.availableModels = models
            if config.selectedModel.isEmpty, let first = models.first {
                config.selectedModel = first.id
            }
        } catch {
            self.availableModels = []
        }
    }

    // MARK: - Chat Messaging

    func sendMessage(
        userText: String,
        note: Note?,
        editorController: EditorController?,
        modelContext: ModelContext?
    ) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isProcessing = true
        errorMessage = nil
        currentStreamingText = ""

        // 1. Save user message to SwiftData
        let userMsg = ChatMessage(
            role: "user",
            content: trimmed,
            modelName: config.selectedModel,
            providerName: config.provider.displayName,
            note: note
        )
        modelContext?.insert(userMsg)
        try? modelContext?.save()

        // 2. Prepare conversation history for OpenAI request
        var openAIMessages: [OpenAIMessage] = []

        var systemPrompt = buildSystemPrompt(note: note, editorController: editorController)

        // Resolve @Note, @Folder, @Memo mentions in user message and inject into context
        let mentionContext = resolveMentions(in: trimmed, modelContext: modelContext, activeNote: note)
        if !mentionContext.isEmpty {
            systemPrompt += "\n\n" + mentionContext
        }

        openAIMessages.append(OpenAIMessage(role: "system", content: systemPrompt))

        // Inject past messages for current note
        if let existingMessages = note?.chatMessages.sorted(by: { $0.timestamp < $1.timestamp }) {
            for m in existingMessages {
                openAIMessages.append(OpenAIMessage(
                    role: m.role,
                    content: m.content,
                    name: m.toolName,
                    toolCallId: m.toolCallId
                ))
            }
        }

        // Filter built-in tools & active MCP tools based on user toggles
        var allTools = LLMToolDefinitions.allTools
        let searchEnabled = UserDefaults.standard.object(forKey: "searchEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "searchEnabled")
        if !searchEnabled {
            allTools.removeAll(where: { $0.function.name == "web_search" })
        }
        if config.isMCPToolsEnabled {
            allTools.append(contentsOf: MCPClientManager.shared.activeTools)
        }

        let router = ToolRouter(
            editorController: editorController,
            modelContext: modelContext,
            currentNote: note
        )

        // 3. Tool Calling loop
        await performChatLoop(
            openAIMessages: &openAIMessages,
            allTools: allTools,
            router: router,
            note: note,
            modelContext: modelContext
        )

        isProcessing = false
    }

    // MARK: - Internal Loop

    private func performChatLoop(
        openAIMessages: inout [OpenAIMessage],
        allTools: [OpenAIToolDefinition],
        router: ToolRouter,
        note: Note?,
        modelContext: ModelContext?
    ) async {
        let model = config.selectedModel.isEmpty ? "default" : config.selectedModel

        do {
            let stream = try await client.chatCompletionStream(
                baseURL: config.baseURL,
                model: model,
                messages: openAIMessages,
                tools: allTools
            )

            var accumulatedText = ""
            var accumulatedReasoning = ""
            var accumulatedToolCalls: [Int: (id: String, name: String, args: String)] = [:]

            for try await delta in stream {
                if let reasoningChunk = delta.reasoningContent, !reasoningChunk.isEmpty {
                    accumulatedReasoning += reasoningChunk
                }

                if let textChunk = delta.content {
                    accumulatedText += textChunk
                }

                if !accumulatedReasoning.isEmpty {
                    if accumulatedText.isEmpty {
                        currentStreamingText = "<think>\(accumulatedReasoning)"
                    } else {
                        currentStreamingText = "<think>\(accumulatedReasoning)</think>\n\n\(accumulatedText)"
                    }
                } else {
                    currentStreamingText = accumulatedText
                }

                if let toolDeltas = delta.toolCalls {
                    for tc in toolDeltas {
                        let idx = tc.index
                        var existing = accumulatedToolCalls[idx] ?? (id: "", name: "", args: "")
                        if let id = tc.id { existing.id = id }
                        if let fnName = tc.function?.name { existing.name += fnName }
                        if let fnArgs = tc.function?.arguments { existing.args += fnArgs }
                        accumulatedToolCalls[idx] = existing
                    }
                }
            }

            let finalAssistantContent: String
            if !accumulatedReasoning.isEmpty && !accumulatedText.contains("<think>") {
                finalAssistantContent = "<think>\n\(accumulatedReasoning.trimmingCharacters(in: .whitespacesAndNewlines))\n</think>\n\n\(accumulatedText)"
            } else {
                finalAssistantContent = accumulatedText
            }

            // Case A: LLM produced assistant text response
            if !finalAssistantContent.isEmpty {
                let assistantMsg = ChatMessage(
                    role: "assistant",
                    content: finalAssistantContent,
                    modelName: model,
                    providerName: config.provider.displayName,
                    note: note
                )
                modelContext?.insert(assistantMsg)
                try? modelContext?.save()
            }

            // Case B: LLM requested tool execution(s)
            if !accumulatedToolCalls.isEmpty {
                var toolCallsToSave: [OpenAIToolCall] = []

                for (_, tc) in accumulatedToolCalls.sorted(by: { $0.key < $1.key }) {
                    let toolCallObj = OpenAIToolCall(
                        id: tc.id,
                        type: "function",
                        function: OpenAIFunctionCall(name: tc.name, arguments: tc.args)
                    )
                    toolCallsToSave.append(toolCallObj)

                    // Execute tool via router
                    let toolResultText = (try? await router.routeAndExecute(name: tc.name, argumentsJSON: tc.args)) ?? "Tool execution failed."

                    // Save tool result to SwiftData & append to messages
                    let toolMsg = ChatMessage(
                        role: "tool",
                        content: toolResultText,
                        toolName: tc.name,
                        toolCallId: tc.id,
                        note: note
                    )
                    modelContext?.insert(toolMsg)
                    try? modelContext?.save()

                    openAIMessages.append(OpenAIMessage(
                        role: "tool",
                        content: toolResultText,
                        name: tc.name,
                        toolCallId: tc.id
                    ))
                }

                // Continue chat loop with tool responses
                await performChatLoop(
                    openAIMessages: &openAIMessages,
                    allTools: allTools,
                    router: router,
                    note: note,
                    modelContext: modelContext
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        currentTask?.cancel()
        isProcessing = false
    }

    // MARK: - Prompt & Context Builder

    private func buildSystemPrompt(note: Note?, editorController: EditorController?) -> String {
        var prompt = """
            You are MDWriter AI — an intelligent native macOS Markdown writing assistant.
            Help the user write, edit, polish, organize, search, and manage notes.
            Use available tools when necessary to read document content, perform edits, manage library notes, or search the web.
            Always format responses in clean Markdown.
            """

        if config.isThinkingEnabled {
            prompt += "\n\n[Reasoning Mode: Enabled]\nThink carefully step-by-step inside <think>...</think> tags before providing your final response."
        } else {
            prompt += "\n\n[Reasoning Mode: Concise]\nRespond directly without extended <think> blocks. /no_think"
        }

        let custom = config.customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            prompt += "\n\n[User Custom Instructions]\n\(custom)"
        }

        switch config.contextLevel {
        case .none:
            break
        case .metadata:
            if let note = note {
                prompt += "\n\n[Active Document Context]\nTitle: \(note.title)\nTags: \(note.tags.joined(separator: ", "))"
                let text = editorController?.fullText ?? note.content
                let wordCount = text.split(whereSeparator: \.isWhitespace).count
                prompt += "\nCharacter Count: \(text.count)\nWord Count: \(wordCount)"
                if let selected = editorController?.proxy.getSelectedText(), !selected.isEmpty {
                    let snippet = selected.count > 200 ? String(selected.prefix(200)) + "..." : selected
                    prompt += "\nSelected Text Snippet: \"\(snippet)\""
                }
            }
        case .full:
            if let note = note {
                let content = editorController?.fullText ?? note.content
                prompt += "\n\n[Active Document Context (Full)]\nTitle: \(note.title)\nTags: \(note.tags.joined(separator: ", "))\nContent:\n\(content)"
                if let selected = editorController?.proxy.getSelectedText(), !selected.isEmpty {
                    prompt += "\nSelected Text: \"\(selected)\""
                }
            }
        }

        return prompt
    }

    // MARK: - Mention Resolver (@Note, @Folder, @Memo)

    private func resolveMentions(in text: String, modelContext: ModelContext?, activeNote: Note?) -> String {
        guard let context = modelContext else { return "" }
        var sections: [String] = []

        // 1. @Note: "title" or @Note:title
        let notePattern = #"(?i)@Note:\s*\"([^\"]+)\"|@Note:([^\s]+)"#
        if let regex = try? NSRegularExpression(pattern: notePattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let noteTitle: String
                if match.range(at: 1).location != NSNotFound {
                    noteTitle = nsText.substring(with: match.range(at: 1))
                } else if match.range(at: 2).location != NSNotFound {
                    noteTitle = nsText.substring(with: match.range(at: 2))
                } else {
                    continue
                }

                let fetchDesc = FetchDescriptor<Note>(predicate: #Predicate { $0.title == noteTitle && !$0.isTrashed })
                if let matchedNote = (try? context.fetch(fetchDesc))?.first {
                    sections.append("[Referenced Note: \"\(matchedNote.title)\"]\n\(matchedNote.content)")
                }
            }
        }

        // 2. @Folder: "name" or @Folder:name
        let folderPattern = #"(?i)@Folder:\s*\"([^\"]+)\"|@Folder:([^\s]+)"#
        if let regex = try? NSRegularExpression(pattern: folderPattern) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let folderName: String
                if match.range(at: 1).location != NSNotFound {
                    folderName = nsText.substring(with: match.range(at: 1))
                } else if match.range(at: 2).location != NSNotFound {
                    folderName = nsText.substring(with: match.range(at: 2))
                } else {
                    continue
                }

                let fetchDesc = FetchDescriptor<Folder>(predicate: #Predicate { $0.name == folderName })
                if let matchedFolder = (try? context.fetch(fetchDesc))?.first {
                    var summary = "[Referenced Folder: \"\(matchedFolder.name)\" (Contains \(matchedFolder.notes.count) notes)]\n"
                    for n in matchedFolder.notes.filter({ !$0.isTrashed }) {
                        let snippet = n.content.count > 300 ? String(n.content.prefix(300)) + "..." : n.content
                        summary += "- **\(n.title)**: \(snippet)\n"
                    }
                    sections.append(summary)
                }
            }
        }

        // 3. @Memo
        if text.localizedCaseInsensitiveContains("@Memo") {
            if let memos = activeNote?.memos, !memos.isEmpty {
                var memoText = "[Referenced Memos for Active Note: \"\(activeNote?.title ?? "")\"]\n"
                for (idx, m) in memos.enumerated() {
                    memoText += "\(idx + 1). \(m.content)\n"
                }
                sections.append(memoText)
            }
        }

        return sections.isEmpty ? "" : "[Referenced Context via @ Mentions]\n" + sections.joined(separator: "\n\n")
    }
}
