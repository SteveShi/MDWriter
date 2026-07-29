//
//  MCPClientManager.swift
//  MDWriter
//

import Foundation

#if canImport(System)
import System
#else
import SystemPackage
#endif

import MCP
import SwiftUI

struct MCPServerStatus: Identifiable, Sendable {
    let id: String
    let name: String
    let isConnected: Bool
    let toolCount: Int
    let errorMessage: String?
}

@Observable
@MainActor
final class MCPClientManager {
    static let shared = MCPClientManager()

    private(set) var activeTools: [OpenAIToolDefinition] = []
    private(set) var statuses: [MCPServerStatus] = []

    private var activeClients: [String: Client] = [:]
    private var activeProcesses: [String: Process] = [:]

    private init() {}

    /// Start and connect all configured MCP servers in mcp.json.
    func reloadAndConnectAll() async {
        await disconnectAll()

        let configs = MCPConfigurationManager.shared.loadConfig()
        var newStatuses: [MCPServerStatus] = []
        var aggregatedTools: [OpenAIToolDefinition] = []

        for config in configs {
            let name = config.name
            guard !config.command.isEmpty else { continue }

            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [config.command] + (config.args ?? [])

                if let env = config.env {
                    var currentEnv = ProcessInfo.processInfo.environment
                    for (k, v) in env {
                        currentEnv[k] = v
                    }
                    process.environment = currentEnv
                }

                let stdinPipe = Pipe()
                let stdoutPipe = Pipe()

                process.standardInput = stdinPipe
                process.standardOutput = stdoutPipe
                process.standardError = FileHandle.nullDevice

                try process.run()

                let transport = StdioTransport(
                    input: FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor),
                    output: FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
                )

                let client = Client(name: "MDWriter", version: "2.7.0")
                try await client.connect(transport: transport)
                let (toolsResult, _) = try await client.listTools()

                var count = 0
                for tool in toolsResult {
                    let openAITool = MCPToolBridge.convertMCPToolToOpenAITool(serverName: name, tool: tool)
                    aggregatedTools.append(openAITool)
                    count += 1
                }

                activeProcesses[name] = process
                activeClients[name] = client
                newStatuses.append(MCPServerStatus(id: name, name: name, isConnected: true, toolCount: count, errorMessage: nil))
            } catch {
                newStatuses.append(MCPServerStatus(id: name, name: name, isConnected: false, toolCount: 0, errorMessage: error.localizedDescription))
            }
        }

        self.statuses = newStatuses
        self.activeTools = aggregatedTools
    }

    /// Disconnect all active MCP clients and terminate processes.
    func disconnectAll() async {
        for (_, client) in activeClients {
            await client.disconnect()
        }
        for (_, proc) in activeProcesses {
            if proc.isRunning {
                proc.terminate()
            }
        }
        activeClients.removeAll()
        activeProcesses.removeAll()
        activeTools.removeAll()
        statuses.removeAll()
    }

    /// Call an MCP tool on target server.
    func callTool(serverName: String, toolName: String, arguments: [String: Value]) async throws -> String {
        guard let client = activeClients[serverName] else {
            throw URLError(.cannotConnectToHost)
        }

        let (contentList, isError) = try await client.callTool(name: toolName, arguments: arguments)
        var resultText = ""
        for content in contentList {
            switch content {
            case .text(let text, _, _):
                resultText += text + "\n"
            case .resource(let resource, _, _):
                resultText += "[Resource: \(resource.uri)]\n"
            case .image(let data, let mimeType, _, _):
                resultText += "[Image (\(mimeType)): \(data.prefix(32))...]\n"
            case .audio(let data, let mimeType, _, _):
                resultText += "[Audio (\(mimeType)): \(data.prefix(32))...]\n"
            case .resourceLink(let uri, _, _, _, _, _):
                resultText += "[ResourceLink: \(uri)]\n"
            }
        }

        if isError == true {
            return "MCP Tool Execution Error:\n" + resultText
        }
        return resultText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
