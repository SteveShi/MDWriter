//
//  MCPToolBridge.swift
//  MDWriter
//

import Foundation
import MCP

/// Helper for converting MCP protocol Tool definitions into OpenAI API Tool format.
struct MCPToolBridge {
    static func convertMCPToolToOpenAITool(serverName: String, tool: MCP.Tool) -> OpenAIToolDefinition {
        let prefixedName = "mcp_\(serverName)_\(tool.name)"
        let desc = tool.description ?? "MCP Tool provided by \(serverName)"

        var paramsObj: [String: Any] = [
            "type": "object",
            "properties": [:] as [String: Any]
        ]

        if let schemaData = try? JSONEncoder().encode(tool.inputSchema),
           let schemaDict = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] {
            paramsObj = schemaDict
        }

        return OpenAIToolDefinition(
            name: prefixedName,
            description: desc,
            parameters: AnyCodable(paramsObj)
        )
    }

    static func parsePrefixedName(_ prefixedName: String) -> (serverName: String, toolName: String)? {
        guard prefixedName.hasPrefix("mcp_") else { return nil }
        let stripped = String(prefixedName.dropFirst(4))
        let parts = stripped.split(separator: "_", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (serverName: parts[0], toolName: parts[1])
    }
}
