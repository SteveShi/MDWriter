//
//  ToolRouter.swift
//  MDWriter
//

import Foundation
import MCP
import SwiftData

/// Central router for dispatching tool calls to built-in tools, web search, or external MCP servers.
@MainActor
final class ToolRouter {
    private let toolExecutor: ToolExecutor

    init(editorController: EditorController? = nil, modelContext: ModelContext? = nil, currentNote: Note? = nil) {
        self.toolExecutor = ToolExecutor(
            editorController: editorController,
            modelContext: modelContext,
            currentNote: currentNote
        )
    }

    func updateContext(editorController: EditorController?, modelContext: ModelContext?, currentNote: Note?) {
        toolExecutor.editorController = editorController
        toolExecutor.modelContext = modelContext
        toolExecutor.currentNote = currentNote
    }

    /// Dispatches tool execution request to appropriate handler.
    func routeAndExecute(name: String, argumentsJSON: String) async throws -> String {
        if let (serverName, toolName) = MCPToolBridge.parsePrefixedName(name) {
            // Parse argumentsJSON string into MCP [String: Value]
            let argsData = argumentsJSON.data(using: .utf8) ?? Data()
            let argsDict = (try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]) ?? [:]
            var mcpArgs: [String: Value] = [:]
            for (k, v) in argsDict {
                mcpArgs[k] = convertAnyToMCPValue(v)
            }
            return try await MCPClientManager.shared.callTool(serverName: serverName, toolName: toolName, arguments: mcpArgs)
        } else {
            return try await toolExecutor.execute(name: name, argumentsJSON: argumentsJSON)
        }
    }

    private func convertAnyToMCPValue(_ val: Any) -> Value {
        switch val {
        case let s as String:
            return .string(s)
        case let b as Bool:
            return .bool(b)
        case let i as Int:
            return .int(i)
        case let d as Double:
            return .double(d)
        case let arr as [Any]:
            return .array(arr.map { convertAnyToMCPValue($0) })
        case let dict as [String: Any]:
            var objectMap: [String: Value] = [:]
            for (k, v) in dict {
                objectMap[k] = convertAnyToMCPValue(v)
            }
            return .object(objectMap)
        default:
            return .string(String(describing: val))
        }
    }
}
