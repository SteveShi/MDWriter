//
//  InlineAIController.swift
//  MDWriter
//
//  Controller managing Inline AI state, prompt execution, streaming, snapshot creation, and text replacement.
//

import AppKit
import Foundation
import SwiftData
import SwiftUI

/// Lifecycle states of the Inline AI Assistant.
enum InlineAIState: Equatable, Sendable {
    case hidden
    case input
    case generating
    case reviewingDiff
}

@MainActor
final class InlineAIController: ObservableObject {
    // MARK: - Published State

    @Published var state: InlineAIState = .hidden
    @Published var userPrompt: String = ""
    @Published var selectedAction: InlineAIAction? = nil

    @Published var originalText: String = ""
    @Published var originalRange: NSRange = NSRange(location: 0, length: 0)
    @Published var generatedText: String = ""
    @Published var reasoningText: String = ""
    @Published var isThinkingExpanded: Bool = false
    @Published var errorMessage: String? = nil

    @Published var caretFrame: CGRect? = nil

    // MARK: - Dependencies & Tasks

    private let openAIClient = OpenAIClient()
    private var streamTask: Task<Void, Never>? = nil

    // Cache of last execution parameters for retry
    private var lastPrompt: String = ""
    private var lastAction: InlineAIAction? = nil

    // MARK: - Public Actions

    /// Toggles the Inline AI bar from the given EditorController.
    func toggle(from controller: EditorController) {
        if state == .hidden {
            show(from: controller)
        } else {
            hide(controller: controller)
        }
    }

    /// Shows the Inline AI prompt bar, capturing selection context and caret geometry.
    func show(from controller: EditorController) {
        cancelGeneration()

        // 1. Capture current selection & text
        let range = controller.proxy.getSelectedRange()
        let selectedText = controller.proxy.getSelectedText() ?? ""

        self.originalRange = range
        self.originalText = selectedText
        self.userPrompt = ""
        self.generatedText = ""
        self.reasoningText = ""
        self.errorMessage = nil
        self.selectedAction = nil

        // 2. Capture caret frame in window coordinates
        self.caretFrame = controller.caretFrameInWindow()

        // 3. Switch to input state
        self.state = .input
    }

    /// Hides the Inline AI bar and returns focus to the editor.
    func hide(controller: EditorController? = nil) {
        cancelGeneration()
        state = .hidden
        userPrompt = ""
        generatedText = ""
        reasoningText = ""
        errorMessage = nil
        selectedAction = nil
        controller?.focusEditor()
    }

    /// Submits a quick preset action or custom user prompt to the LLM.
    func submit(
        action: InlineAIAction? = nil,
        prompt: String? = nil,
        note: Note?,
        controller: EditorController,
        modelContext: ModelContext?
    ) {
        let actionToUse = action ?? selectedAction
        let customPrompt = (prompt ?? userPrompt).trimmingCharacters(in: .whitespacesAndNewlines)

        guard actionToUse != nil || !customPrompt.isEmpty else { return }

        self.lastAction = actionToUse
        self.lastPrompt = customPrompt
        self.selectedAction = actionToUse

        startStreaming(action: actionToUse, customPrompt: customPrompt, note: note, controller: controller, modelContext: modelContext)
    }

    /// Retries the last action or prompt.
    func retry(note: Note?, controller: EditorController, modelContext: ModelContext?) {
        guard lastAction != nil || !lastPrompt.isEmpty else { return }
        startStreaming(action: lastAction, customPrompt: lastPrompt, note: note, controller: controller, modelContext: modelContext)
    }

    /// Accepts the suggested changes, automatically creating a safety snapshot and applying the text update.
    func accept(controller: EditorController, note: Note?, modelContext: ModelContext?) {
        guard !generatedText.isEmpty else {
            hide(controller: controller)
            return
        }

        // 1. Create safety snapshot before altering user document
        createSafetySnapshot(note: note, controller: controller, modelContext: modelContext)

        // 2. Apply replacement or insertion
        if originalRange.length > 0 {
            controller.proxy.replace(range: originalRange, with: generatedText)
        } else {
            controller.proxy.insert(generatedText)
        }

        // 3. Persist note modifications
        note?.modifiedAt = Date()
        try? modelContext?.save()

        // 4. Return to normal state
        hide(controller: controller)
    }

    /// Rejects the suggested changes without altering document text.
    func reject(controller: EditorController) {
        hide(controller: controller)
    }

    // MARK: - Private Streaming Implementation

    private func startStreaming(
        action: InlineAIAction?,
        customPrompt: String,
        note: Note?,
        controller: EditorController,
        modelContext: ModelContext?
    ) {
        cancelGeneration()

        self.state = .generating
        self.generatedText = ""
        self.reasoningText = ""
        self.errorMessage = nil

        let config = LLMConfiguration.shared

        // Build messages
        let systemPrompt = """
        You are MDWriter's native macOS Inline Writing Assistant.
        You perform focused, high-precision text modifications directly in the user's document.
        Rules:
        1. Output ONLY the resulting Markdown replacement or continuation text.
        2. Do NOT add preamble, conversational remarks, or conversational closing (e.g. no "Here is your text:", no quotes around the output).
        3. Preserve original Markdown formatting (bold, italic, links, lists, code) unless explicitly requested otherwise.
        """

        var instructionText = ""
        if let action = action {
            instructionText = action.instruction(for: originalText)
        } else {
            instructionText = customPrompt
        }

        var userMessageContent = ""
        if !originalText.isEmpty {
            userMessageContent = """
            Instruction: \(instructionText)

            [Selected Text to Transform]:
            \(originalText)
            """
        } else {
            // Provide nearby context if available
            let fullText = controller.fullText.isEmpty ? (note?.content ?? "") : controller.fullText
            userMessageContent = """
            Instruction: \(instructionText)

            [Document Context]:
            \(fullText.prefix(2000))
            """
        }

        let messages = [
            OpenAIMessage(role: "system", content: systemPrompt),
            OpenAIMessage(role: "user", content: userMessageContent)
        ]

        streamTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let stream = try await self.openAIClient.chatCompletionStream(
                    baseURL: config.baseURL,
                    model: config.selectedModel.isEmpty ? "default" : config.selectedModel,
                    messages: messages
                )

                for try await delta in stream {
                    guard !Task.isCancelled else { break }

                    if let content = delta.content {
                        self.generatedText += content
                    }
                    if let reasoning = delta.reasoningContent {
                        self.reasoningText += reasoning
                    }
                }

                // If streaming succeeded and task wasn't cancelled, transition to Diff Review
                if !Task.isCancelled {
                    let cleaned = self.generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.isEmpty {
                        self.errorMessage = String(localized: "No content generated. Please try again.")
                        self.state = .input
                    } else {
                        self.generatedText = cleaned
                        self.state = .reviewingDiff
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.state = .input
                }
            }
        }
    }

    private func cancelGeneration() {
        streamTask?.cancel()
        streamTask = nil
    }

    // MARK: - Snapshot Helper

    private func createSafetySnapshot(note: Note?, controller: EditorController, modelContext: ModelContext?) {
        guard let note = note else { return }
        let currentContent = (controller.fullText.isEmpty == false ? controller.fullText : note.content)
        guard !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Deduplicate against latest snapshot
        if let latest = note.snapshots.sorted(by: { $0.createdAt > $1.createdAt }).first,
           latest.content == currentContent {
            return
        }

        let snapshot = Snapshot(content: currentContent, note: note)
        modelContext?.insert(snapshot)
        note.snapshots.append(snapshot)
        try? modelContext?.save()
    }
}
