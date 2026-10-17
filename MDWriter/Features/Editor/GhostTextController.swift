//
//  GhostTextController.swift
//  MDWriter
//
//  Inline ghost text autocomplete prediction and Tab-to-accept manager for distraction-free writing.
//

import AppKit
import Foundation
import SwiftUI

/// Controller providing real-time ghost text predictions when the user pauses typing.
@MainActor
final class GhostTextController: ObservableObject {
    static let shared = GhostTextController()

    @Published var ghostSuggestion: String = ""
    @Published var isPredicting: Bool = false
    @AppStorage("ghostTextEnabled") var isEnabled: Bool = true

    private var debounceTask: Task<Void, Never>? = nil
    private let client = OpenAIClient()

    // MARK: - Typing Notification Hook

    /// Called whenever text or selection changes in the editor.
    func handleEditorChange(controller: EditorController) {
        guard isEnabled else {
            clear()
            return
        }

        debounceTask?.cancel()

        let selection = controller.proxy.getSelectedRange()
        // Only predict at caret (length == 0) and not at the very start of document
        guard selection.length == 0, selection.location > 5 else {
            clear()
            return
        }

        let fullText = controller.fullText
        guard !fullText.isEmpty, selection.location <= fullText.count else {
            clear()
            return
        }

        // Schedule prediction after 1.2s pause
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await self?.requestPrediction(around: selection.location, in: fullText)
        }
    }

    /// Accepts the current ghost suggestion and inserts it at the caret.
    func accept(into controller: EditorController) {
        guard !ghostSuggestion.isEmpty else { return }
        let suggestionToInsert = ghostSuggestion
        clear()
        controller.proxy.insert(suggestionToInsert)
    }

    /// Dismisses the active suggestion.
    func dismiss() {
        clear()
    }

    private func clear() {
        debounceTask?.cancel()
        ghostSuggestion = ""
        isPredicting = false
    }

    // MARK: - Prediction Request

    private func requestPrediction(around caretPos: Int, in fullText: String) async {
        let ns = fullText as NSString
        let prefixRange = NSRange(location: max(0, caretPos - 300), length: min(300, caretPos))
        let contextPrefix = ns.substring(with: prefixRange).trimmingCharacters(in: .whitespacesAndNewlines)

        guard contextPrefix.count >= 10 else { return }

        self.isPredicting = true

        let config = LLMConfiguration.shared
        guard config.isLLMEnabled else {
            self.isPredicting = false
            return
        }

        let systemPrompt = """
        You are an instant ghost-text writing completion engine.
        Predict and continue the text with ONLY the immediate next 10 to 25 characters or 1 short sentence fragment.
        Do NOT repeat the prefix. Do NOT output conversational filler or quotes.
        """

        let messages = [
            OpenAIMessage(role: "system", content: systemPrompt),
            OpenAIMessage(role: "user", content: contextPrefix)
        ]

        do {
            let stream = try await client.chatCompletionStream(
                baseURL: config.baseURL,
                model: config.selectedModel.isEmpty ? "default" : config.selectedModel,
                messages: messages
            )

            var accumulated = ""
            for try await delta in stream {
                guard !Task.isCancelled else { break }
                if let content = delta.content {
                    accumulated += content
                    if accumulated.count > 60 || accumulated.contains("\n") {
                        break
                    }
                }
            }

            let cleaned = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
            if !Task.isCancelled && !cleaned.isEmpty {
                self.ghostSuggestion = cleaned
            }
        } catch {
            // Silently ignore prediction errors to never interrupt writing flow
        }

        self.isPredicting = false
    }
}
