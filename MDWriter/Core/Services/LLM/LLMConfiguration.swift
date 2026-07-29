//
//  LLMConfiguration.swift
//  MDWriter
//

import Foundation
import SwiftUI

enum AIContextLevel: String, CaseIterable, Identifiable, Sendable {
    case none
    case metadata
    case full

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Off"
        case .metadata: return "Metadata"
        case .full: return "Full Doc"
        }
    }
}

/// Configuration & state manager for local LLM engine connections.
@Observable
@MainActor
final class LLMConfiguration {
    // MARK: - Properties

    var provider: LLMProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "llmProvider") ?? LLMProvider.ollama.rawValue
            return LLMProvider(rawValue: raw) ?? .ollama
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "llmProvider")
        }
    }

    var customBaseURL: String {
        get {
            UserDefaults.standard.string(forKey: "llmCustomBaseURL") ?? LLMProvider.ollama.defaultBaseURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "llmCustomBaseURL")
        }
    }

    var selectedModel: String {
        get {
            UserDefaults.standard.string(forKey: "llmSelectedModel") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "llmSelectedModel")
        }
    }

    var isLLMEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "llmEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "llmEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "llmEnabled")
        }
    }

    // MARK: - Advanced AI Settings

    var contextLevel: AIContextLevel {
        get {
            let raw = UserDefaults.standard.string(forKey: "aiContextLevel") ?? AIContextLevel.metadata.rawValue
            return AIContextLevel(rawValue: raw) ?? .metadata
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "aiContextLevel")
        }
    }

    var customSystemPrompt: String {
        get {
            UserDefaults.standard.string(forKey: "aiCustomSystemPrompt") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "aiCustomSystemPrompt")
        }
    }

    var isThinkingEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "aiThinkingEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "aiThinkingEnabled")
        }
    }

    var isMCPToolsEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "mcpToolsEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "mcpToolsEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "mcpToolsEnabled")
        }
    }

    // MARK: - Computed Base URL

    var baseURL: String {
        let trimmed = customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        }
        return provider.defaultBaseURL
    }

    // MARK: - Auto Detection

    /// Detects active local LLM providers by probing common ports in order.
    func autoDetectProvider() async -> LLMProvider? {
        let client = OpenAIClient()
        for candidate in LLMProvider.allCases where candidate != .custom {
            let url = candidate.defaultBaseURL
            if await client.healthCheck(baseURL: url, provider: candidate) {
                self.provider = candidate
                self.customBaseURL = url
                return candidate
            }
        }
        return nil
    }
}
