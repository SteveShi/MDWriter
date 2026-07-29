//
//  SSEParser.swift
//  MDWriter
//

import Foundation

/// Data structure representing incremental content or tool call updates from OpenAI-compatible SSE streams.
struct ChatStreamDelta: Sendable {
    let content: String?
    let toolCalls: [ToolCallDelta]?
    let finishReason: String?
}

struct ToolCallDelta: Sendable, Codable {
    let index: Int
    let id: String?
    let type: String?
    let function: FunctionDelta?
}

struct FunctionDelta: Sendable, Codable {
    let name: String?
    let arguments: String?
}

// MARK: - Internal SSE Response Models

private struct SSEServerResponse: Codable {
    let choices: [SSEServerChoice]?
}

private struct SSEServerChoice: Codable {
    let delta: SSEServerDelta?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

private struct SSEServerDelta: Codable {
    let content: String?
    let toolCalls: [ToolCallDelta]?

    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

// MARK: - SSE Parser

/// Parser for Server-Sent Events (SSE) from OpenAI `/v1/chat/completions` API endpoints.
final class SSEParser: Sendable {
    private let decoder = JSONDecoder()

    /// Parses an incoming URLSession AsyncBytes stream into a stream of `ChatStreamDelta`.
    func parseStream(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<ChatStreamDelta, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        guard trimmed.hasPrefix("data:") else { continue }

                        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" {
                            break
                        }

                        guard let data = payload.data(using: .utf8) else { continue }
                        if let response = try? decoder.decode(SSEServerResponse.self, from: data),
                           let choice = response.choices?.first {
                            let delta = ChatStreamDelta(
                                content: choice.delta?.content,
                                toolCalls: choice.delta?.toolCalls,
                                finishReason: choice.finishReason
                            )
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
