//
//  AIModels.swift
//  MDWriter
//
//  Structured output models for Apple Foundation Models (Guided Generation).
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Tag Suggestions

@available(macOS 26.0, *)
@Generable
struct TagSuggestions {
    @Guide(description: "A list of 3 to 5 concise keyword tags that describe the main topics of the document. Each tag should be a single word or short phrase.")
    var tags: [String]
}

// MARK: - Proofread Result

@available(macOS 26.0, *)
@Generable
struct ProofreadResult {
    @Guide(description: "The corrected version of the original text with grammar and spelling fixes applied.")
    var correctedText: String

    @Guide(description: "A list of corrections that were made, each describing what was changed and why.")
    var corrections: [String]
}

// MARK: - Translation Result

@available(macOS 26.0, *)
@Generable
struct TranslationResult {
    @Guide(description: "The translated text in the target language.")
    var translatedText: String
}

// MARK: - Title Suggestion

@available(macOS 26.0, *)
@Generable
struct TitleSuggestion {
    @Guide(description: "A concise, descriptive title for the document, no more than 10 words.")
    var title: String
}

// MARK: - Summary Result

@available(macOS 26.0, *)
@Generable
struct SummaryResult {
    @Guide(description: "A concise summary of the document in 2-3 sentences.")
    var summary: String
}

#endif
