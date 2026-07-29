//
//  AIAction.swift
//  MDWriter
//

import Foundation
import SwiftUI

enum AIActionBackend: Sendable {
    case appleAI
    case localLLM
}

enum AIAction: String, CaseIterable, Identifiable, Sendable {
    // Apple Intelligence lightweight actions
    case summarize = "summarize"
    case generateTitle = "generateTitle"
    case suggestTags = "suggestTags"
    case translate = "translate"

    // Local LLM complex actions
    case polish = "polish"
    case proofread = "proofread"
    case toneAdjust = "toneAdjust"
    case expand = "expand"
    case toTable = "toTable"
    case formatMarkdown = "formatMarkdown"

    var id: String { rawValue }

    var backend: AIActionBackend {
        switch self {
        case .summarize, .generateTitle, .suggestTags, .translate:
            return .appleAI
        case .polish, .proofread, .toneAdjust, .expand, .toTable, .formatMarkdown:
            return .localLLM
        }
    }

    var displayName: LocalizedStringKey {
        switch self {
        case .summarize: return LocalizedStringKey("Summarize")
        case .generateTitle: return LocalizedStringKey("Smart Title")
        case .suggestTags: return LocalizedStringKey("Auto Tags")
        case .translate: return LocalizedStringKey("Quick Translate")
        case .polish: return LocalizedStringKey("Polish & Rewrite")
        case .proofread: return LocalizedStringKey("Deep Proofread")
        case .toneAdjust: return LocalizedStringKey("Adjust Tone")
        case .expand: return LocalizedStringKey("Expand Content")
        case .toTable: return LocalizedStringKey("Convert to Table")
        case .formatMarkdown: return LocalizedStringKey("Format Markdown")
        }
    }

    var icon: String {
        switch self {
        case .summarize: return "doc.plaintext"
        case .generateTitle: return "textformat"
        case .suggestTags: return "tag"
        case .translate: return "globe"
        case .polish: return "wand.and.stars"
        case .proofread: return "checkmark.circle"
        case .toneAdjust: return "slider.horizontal.3"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .toTable: return "tablecells"
        case .formatMarkdown: return "text.alignleft"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .summarize: return LocalizedStringKey("Generate a concise summary of the content")
        case .generateTitle: return LocalizedStringKey("Generate a descriptive title based on the content")
        case .suggestTags: return LocalizedStringKey("Suggest keyword tags for the document")
        case .translate: return LocalizedStringKey("Fast on-device translation")
        case .polish: return LocalizedStringKey("Improve clarity, tone, and flow using local LLM")
        case .proofread: return LocalizedStringKey("Deep grammar and spelling correction")
        case .toneAdjust: return LocalizedStringKey("Switch between academic, casual, or professional tone")
        case .expand: return LocalizedStringKey("Expand outline points into detailed paragraphs")
        case .toTable: return LocalizedStringKey("Transform unorganized text into Markdown table")
        case .formatMarkdown: return LocalizedStringKey("Clean up and format Markdown syntax")
        }
    }
}
