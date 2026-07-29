//
//  AIService.swift
//  MDWriter
//
//  Core AI service wrapping Apple Foundation Models framework for lightweight on-device tasks.
//

import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels

// MARK: - AI Service

@available(macOS 26.0, *)
@Observable
@MainActor
class AIService {

    // MARK: - State

    var isProcessing: Bool = false
    var result: String = ""
    var errorMessage: String?
    var suggestedTags: [String] = []
    var corrections: [String] = []

    // MARK: - Availability

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var availabilityDescription: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return String(localized: "AI Ready")
        case .unavailable:
            return String(localized: "AI Unavailable")
        }
    }

    // MARK: - Session Management

    private func createSession(for action: AIAction) -> LanguageModelSession {
        let instructions: String
        switch action {
        case .polish:
            instructions = """
                You are a professional writing assistant. Your task is to polish and improve text \
                while preserving its original meaning and tone. Improve clarity, readability, and \
                flow. Output only the improved text, nothing else.
                """
        case .summarize:
            instructions = """
                You are a summarization assistant. Generate a concise summary of the given text \
                in 2-3 sentences. The summary should capture the key points and main ideas. \
                Output only the summary, nothing else.
                """
        case .translate:
            let target = UserDefaults.standard.string(forKey: "aiTranslationTarget") ?? "auto"
            let targetInstruction: String
            switch target {
            case "en":
                targetInstruction = "Translate the input text to English."
            case "zh-Hans":
                targetInstruction = "Translate the input text to Simplified Chinese."
            default:
                targetInstruction = "If the input text is in Chinese, translate it to English. If the input text is in English or another language, translate it to Simplified Chinese."
            }
            instructions = """
                You are a professional translator. \(targetInstruction) Preserve formatting including Markdown syntax. \
                Output only the translated text, nothing else.
                """
        case .generateTitle:
            instructions = """
                You are a title generation assistant. Based on the content provided, generate a \
                single concise and descriptive title. The title should be no more than 10 words. \
                If the content is in Chinese, generate a Chinese title. If in English, generate \
                an English title. Output only the title, nothing else.
                """
        case .proofread:
            instructions = """
                You are a proofreading assistant. Check the text for grammar, spelling, and \
                punctuation errors. Fix any issues found while preserving the original meaning \
                and style.
                """
        case .suggestTags:
            instructions = """
                You are a content classification assistant. Analyze the document and suggest \
                3-5 concise keyword tags that describe its main topics. Tags should be single \
                words or short phrases.
                """
        default:
            instructions = "You are an AI assistant."
        }

        return LanguageModelSession(instructions: instructions)
    }

    // MARK: - Actions

    /// Generate summary
    func summarize(text: String) async {
        await performTextAction(.summarize, input: text, prompt: text)
    }

    /// Translate (auto-detect direction)
    func translate(text: String) async {
        await performTextAction(.translate, input: text, prompt: text)
    }

    /// Generate title
    func generateTitle(for text: String) async {
        await performTextAction(.generateTitle, input: text, prompt: text)
    }

    /// Suggest tags with structured output
    func suggestTags(for text: String) async {
        isProcessing = true
        result = ""
        errorMessage = nil
        suggestedTags = []

        do {
            let session = createSession(for: .suggestTags)
            let response = try await session.respond(
                to: text,
                generating: TagSuggestions.self
            )
            suggestedTags = response.content.tags
            result = response.content.tags.joined(separator: ", ")
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    // MARK: - Streaming Text Action

    private func performTextAction(_ action: AIAction, input: String, prompt: String) async {
        isProcessing = true
        result = ""
        errorMessage = nil

        do {
            let session = createSession(for: action)
            let stream = session.streamResponse(to: prompt)

            for try await partial in stream {
                result = partial.content
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    /// Reset state
    func reset() {
        isProcessing = false
        result = ""
        errorMessage = nil
        suggestedTags = []
        corrections = []
    }
}

#endif
