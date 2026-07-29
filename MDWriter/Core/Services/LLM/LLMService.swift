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

        // System prompt with contextual instructions
        let systemPrompt = """
            You are MDWriter AI, an intelligent native macOS Markdown writing assistant.
            Help the user write, edit, polish, organize, search, and manage notes.
            Use available tools when necessary to read document content, perform edits, manage library notes, or search the web.
            Format responses in clean Markdown.
            """
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

        // Merge built-in tools with active MCP tools
        var allTools = LLMToolDefinitions.allTools
        allTools.append(contentsOf: MCPClientManager.shared.activeTools)

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
}
