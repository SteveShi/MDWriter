//
//  LLMProvider.swift
//  MDWriter
//

import Foundation
import SwiftUI

/// Supported local LLM inference engines.
enum LLMProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case ollama = "ollama"
    case lmStudio = "lmStudio"
    case omlx = "omlx"
    case llamaCpp = "llamaCpp"
    case mlx = "mlx"
    case jan = "jan"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .lmStudio: return "LM Studio"
        case .omlx: return "oMLX"
        case .llamaCpp: return "llama.cpp"
        case .mlx: return "MLX (mlx-lm)"
        case .jan: return "Jan"
        case .custom: return String(localized: "Custom Server")
        }
    }

    var iconName: String {
        switch self {
        case .ollama: return "cpu"
        case .lmStudio: return "desktopcomputer"
        case .omlx: return "memorychip"
        case .llamaCpp: return "terminal"
        case .mlx: return "apple.logo"
        case .jan: return "app.badge"
        case .custom: return "network"
        }
    }

    var defaultPort: Int {
        switch self {
        case .ollama: return 11434
        case .lmStudio: return 1234
        case .omlx: return 8000
        case .llamaCpp, .mlx: return 8080
        case .jan: return 1337
        case .custom: return 8080
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .ollama:
            return "http://localhost:11434"
        case .lmStudio:
            return "http://localhost:1234"
        case .omlx:
            return "http://localhost:8000"
        case .llamaCpp, .mlx:
            return "http://localhost:8080"
        case .jan:
            return "http://127.0.0.1:1337"
        case .custom:
            return "http://localhost:8080"
        }
    }

    /// Health check path or ping path relative to base URL
    var healthCheckPath: String {
        switch self {
        case .ollama:
            return "/"
        case .llamaCpp:
            return "/health"
        case .lmStudio, .omlx, .mlx, .jan, .custom:
            return "/v1/models"
        }
    }

    /// Primary model list path
    var modelsPath: String {
        return "/v1/models"
    }

    /// Chat completions path
    var chatCompletionsPath: String {
        return "/v1/chat/completions"
    }
}
