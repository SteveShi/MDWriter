//
//  MCPConfiguration.swift
//  MDWriter
//

import Foundation

/// Data models for `mcp.json` server configurations.
struct MCPConfigFile: Codable, Sendable {
    var mcpServers: [String: MCPServerConfig]
}

struct MCPServerConfig: Codable, Sendable, Identifiable {
    var id: String { name }

    var name: String = ""
    var command: String
    var args: [String]?
    var env: [String: String]?

    enum CodingKeys: String, CodingKey {
        case command
        case args
        case env
    }

    init(name: String = "", command: String, args: [String]? = nil, env: [String: String]? = nil) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }
}

/// Helper for loading and saving `mcp.json` configuration file.
final class MCPConfigurationManager: Sendable {
    static let shared = MCPConfigurationManager()

    var configFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("MDWriter", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("mcp.json")
    }

    func loadConfig() -> [MCPServerConfig] {
        let url = configFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(MCPConfigFile.self, from: data) else {
            return []
        }

        var result: [MCPServerConfig] = []
        for (name, var config) in decoded.mcpServers {
            config.name = name
            result.append(config)
        }
        return result.sorted(by: { $0.name < $1.name })
    }

    func saveConfig(servers: [MCPServerConfig]) throws {
        var map: [String: MCPServerConfig] = [:]
        for var s in servers {
            let name = s.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            s.name = "" // exclude name from inner dict
            map[name] = s
        }

        let file = MCPConfigFile(mcpServers: map)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: configFileURL)
    }
}
