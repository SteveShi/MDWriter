//
//  AIService.swift
//  MDWriter
//
//  Core AI service wrapping Apple Foundation Models framework.
//  All inference happens on-device for privacy.
//

import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels

// MARK: - AI Action Type

enum AIAction: String, CaseIterable, Identifiable {
    case polish = "polish"
    case summarize = "summarize"
    case translate = "translate"
    case generateTitle = "generateTitle"
    case proofread = "proofread"
    case suggestTags = "suggestTags"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .polish: return LocalizedStringKey("Polish")
        case .summarize: return LocalizedStringKey("Summarize")
        case .translate: return LocalizedStringKey("Translate")
        case .generateTitle: return LocalizedStringKey("Smart Title")
        case .proofread: return LocalizedStringKey("Proofread")
        case .suggestTags: return LocalizedStringKey("Auto Tags")
        }
    }

    var icon: String {
        switch self {
        case .polish: return "wand.and.stars"
        case .summarize: return "doc.plaintext"
        case .translate: return "globe"
        case .generateTitle: return "textformat"
        case .proofread: return "checkmark.circle"
        case .suggestTags: return "tag"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .polish: return LocalizedStringKey("Rewrite and improve the text while preserving its meaning")
        case .summarize: return LocalizedStringKey("Generate a concise summary of the content")
        case .translate: return LocalizedStringKey("Translate between Chinese and English")
        case .generateTitle: return LocalizedStringKey("Generate a descriptive title based on the content")
        case .proofread: return LocalizedStringKey("Check grammar and spelling errors")
        case .suggestTags: return LocalizedStringKey("Suggest keyword tags for the document")
        }
    }
}

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
            return NSLocalizedString("AI Ready", comment: "")
        case .unavailable:
            return NSLocalizedString("AI Unavailable", comment: "")
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
            instructions = """
                You are a professional translator. If the input text is in Chinese, translate it \
                to English. If the input text is in English or another language, translate it to \
                Simplified Chinese. Preserve formatting including Markdown syntax. \
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
        }

        return LanguageModelSession(instructions: instructions)
    }

    // MARK: - Actions

    /// Polish / rewrite text
    func polish(text: String) async {
        await performTextAction(.polish, input: text, prompt: text)
    }

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

    /// Proofread with structured output
    func proofread(text: String) async {
        isProcessing = true
        result = ""
        errorMessage = nil
        corrections = []

        do {
            let session = createSession(for: .proofread)
            let response = try await session.respond(
                to: text,
                generating: ProofreadResult.self
            )
            result = response.content.correctedText
            corrections = response.content.corrections
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
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
