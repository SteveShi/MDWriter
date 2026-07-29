//
//  OpenAIClient.swift
//  MDWriter
//

import Foundation

// MARK: - OpenAIMessage Models

struct LLMModelResponse: Codable, Sendable {
    let data: [LLMModel]
}

struct LLMModel: Identifiable, Sendable, Codable, Hashable {
    let id: String
    let object: String?
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case ownedBy = "owned_by"
    }
}

struct OpenAIMessage: Codable, Sendable {
    let role: String
    let content: String?
    let name: String?
    let toolCallId: String?
    let toolCalls: [OpenAIToolCall]?

    init(
        role: String,
        content: String?,
        name: String? = nil,
        toolCallId: String? = nil,
        toolCalls: [OpenAIToolCall]? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }

    enum CodingKeys: String, CodingKey {
        case role, content, name
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }
}

struct OpenAIToolCall: Codable, Sendable, Identifiable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

struct OpenAIFunctionCall: Codable, Sendable {
    let name: String
    let arguments: String
}

struct OpenAIToolDefinition: Codable, Sendable {
    let type: String
    let function: OpenAIFunctionDefinition

    init(name: String, description: String, parametersData: Data) {
        self.type = "function"
        let params = (try? JSONSerialization.jsonObject(with: parametersData) as? [String: Any]) ?? [:]
        self.function = OpenAIFunctionDefinition(name: name, description: description, parameters: AnyCodable(params))
    }

    init(name: String, description: String, parameters: AnyCodable) {
        self.type = "function"
        self.function = OpenAIFunctionDefinition(name: name, description: description, parameters: parameters)
    }
}

struct OpenAIFunctionDefinition: Codable, Sendable {
    let name: String
    let description: String
    let parameters: AnyCodable
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable, Sendable {
    let value: AnySendable

    init(_ value: Any) {
        self.value = AnySendable(value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = AnySendable(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            value = AnySendable(doubleVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            value = AnySendable(boolVal)
        } else if let stringVal = try? container.decode(String.self) {
            value = AnySendable(stringVal)
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = AnySendable(arrayVal.map { $0.value.raw })
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            var d: [String: Any] = [:]
            for (k, v) in dictVal {
                d[k] = v.value.raw
            }
            value = AnySendable(d)
        } else {
            value = AnySendable(NSNull())
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try encodeValue(value.raw, into: &container)
    }

    private func encodeValue(_ val: Any, into container: inout SingleValueEncodingContainer) throws {
        switch val {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let arrayVal as [Any]:
            let codableArray = arrayVal.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictVal as [String: Any]:
            let codableDict = dictVal.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        default:
            try container.encodeNil()
        }
    }
}

struct AnySendable: @unchecked Sendable {
    let raw: Any
    init(_ raw: Any) { self.raw = raw }
}

// MARK: - OpenAI Client

/// HTTP client for OpenAI-compatible LLM server endpoints.
final class OpenAIClient: Sendable {
    private let session: URLSession
    private let sseParser = SSEParser()

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Perform health check against target engine.
    func healthCheck(baseURL: String, provider: LLMProvider) async -> Bool {
        let endpoint = baseURL + provider.healthCheckPath
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0

        do {
            let (_, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse {
                return (200...299).contains(httpRes.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    /// List available models from LLM server.
    func listModels(baseURL: String) async throws -> [LLMModel] {
        let endpoint = baseURL + "/v1/models"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let modelRes = try JSONDecoder().decode(LLMModelResponse.self, from: data)
        return modelRes.data
    }

    /// Send chat completion request with streaming.
    func chatCompletionStream(
        baseURL: String,
        model: String,
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]? = nil
    ) async throws -> AsyncThrowingStream<ChatStreamDelta, Error> {
        let endpoint = baseURL + "/v1/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": try messagesToDictionaries(messages),
            "stream": true
        ]

        if let tools = tools, !tools.isEmpty {
            requestBody["tools"] = try toolsToDictionaries(tools)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60.0

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return sseParser.parseStream(bytes: bytes)
    }

    // MARK: - Helpers

    private func messagesToDictionaries(_ messages: [OpenAIMessage]) throws -> [[String: Any]] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(messages)
        let json = try JSONSerialization.jsonObject(with: data)
        return (json as? [[String: Any]]) ?? []
    }

    private func toolsToDictionaries(_ tools: [OpenAIToolDefinition]) throws -> [[String: Any]] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(tools)
        let json = try JSONSerialization.jsonObject(with: data)
        return (json as? [[String: Any]]) ?? []
    }
}
