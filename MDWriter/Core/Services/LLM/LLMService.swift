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

        let systemPrompt = buildSystemPrompt(note: note, editorController: editorController)
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
            var accumulatedToolCalls: [Int: (id: String, name: String, args: String)] = [:]

            for try await delta in stream {
                if let textChunk = delta.content {
                    accumulatedText += textChunk
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

            // Case A: LLM produced assistant text response
            if !accumulatedText.isEmpty {
                let assistantMsg = ChatMessage(
                    role: "assistant",
                    content: accumulatedText,
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
}
