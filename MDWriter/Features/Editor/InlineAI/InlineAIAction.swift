//
//  InlineAIAction.swift
//  MDWriter
//
//  Predefined quick actions and prompt templates for Inline AI editing and generation.
//

import Foundation
import SwiftUI

/// Preset inline action supported by the Inline AI Assistant.
enum InlineAIAction: String, CaseIterable, Identifiable, Sendable {
    case polish
    case shorten
    case expand
    case fixGrammar
    case translate
    case professional
    case casual
    case continueWriting

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .polish: return "Polish"
        case .shorten: return "Shorten"
        case .expand: return "Expand"
        case .fixGrammar: return "Fix Grammar"
        case .translate: return "Translate"
        case .professional: return "Professional"
        case .casual: return "Casual"
        case .continueWriting: return "Continue"
        }
    }

    var icon: String {
        switch self {
        case .polish: return "wand.and.stars"
        case .shorten: return "arrow.down.right.and.arrow.up.left"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .fixGrammar: return "checkmark.bubble"
        case .translate: return "character.book.closed"
        case .professional: return "briefcase"
        case .casual: return "face.smiling"
        case .continueWriting: return "text.badge.plus"
        }
    }

    /// Whether this action requires or preferentially targets selected text.
    var requiresSelection: Bool {
        switch self {
        case .continueWriting:
            return false
        default:
            return true
        }
    }

    /// Generates the instruction prompt for the model given user selection and note context.
    func instruction(for selectedText: String?) -> String {
        switch self {
        case .polish:
            return "Please polish and refine the selected text to make it more elegant, fluent, and natural, while preserving its exact original meaning and Markdown formatting. Output only the revised text without explanations."
        case .shorten:
            return "Please make the selected text more concise and punchy by trimming redundant words while keeping all core facts and intent. Output only the shortened text without explanations."
        case .expand:
            return "Please expand on the selected text with richer context, vivid explanations, and relevant details, maintaining an appropriate writing style. Output only the expanded text without explanations."
        case .fixGrammar:
            return "Please check and fix all grammatical, spelling, punctuation, and phrasing errors in the selected text. Output only the corrected text without explanations."
        case .translate:
            return "Please translate the selected text naturally. If it is in Chinese, translate it to polished English; if it is in English or another language, translate it to natural Simplified Chinese. Output only the translated text without explanations."
        case .professional:
            return "Please rewrite the selected text in an authoritative, professional, and clear tone suitable for business or technical documentation. Output only the revised text without explanations."
        case .casual:
            return "Please rewrite the selected text in a warm, relaxed, conversational, and approachable tone. Output only the revised text without explanations."
        case .continueWriting:
            return "Please continue writing seamlessly from where the text leaves off, matching the tone, style, and Markdown structure of the preceding content. Output only the continuation without conversational filler."
        }
    }
}
