//
//  ChatMessage.swift
//  MDWriter
//

import Foundation
import SwiftData

/// SwiftData persistent storage for LLM chat messages associated with a Note.
@Model
final class ChatMessage {
    var id: UUID
    var role: String                   // "user", "assistant", "system", "tool"
    var content: String
    var timestamp: Date
    var modelName: String?             // e.g. "qwen2.5:14b"
    var providerName: String?          // e.g. "Ollama"
    var toolCallsData: Data?           // Encoded JSON tool calls
    var toolName: String?              // Name of tool when role == "tool"
    var toolCallId: String?            // ID of tool call when role == "tool"
    var searchSourcesData: Data?       // Encoded JSON search sources

    var note: Note?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        modelName: String? = nil,
        providerName: String? = nil,
        toolCallsData: Data? = nil,
        toolName: String? = nil,
        toolCallId: String? = nil,
        searchSourcesData: Data? = nil,
        note: Note? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.modelName = modelName
        self.providerName = providerName
        self.toolCallsData = toolCallsData
        self.toolName = toolName
        self.toolCallId = toolCallId
        self.searchSourcesData = searchSourcesData
        self.note = note
    }
}
