//
//  MCPSettingsView.swift
//  MDWriter
//

import AppKit
import SwiftUI

struct MCPPresetTemplate: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let description: String
    let command: String
    let args: String
    let requiresFolder: Bool
    let requiresApiKey: Bool
    let envKey: String?
}

let mcpPresets: [MCPPresetTemplate] = [
    MCPPresetTemplate(
        id: "filesystem",
        name: "📁 Local Filesystem (Filesystem)",
        iconName: "folder.badge.gear",
        description: "Allow AI to read and manage Markdown notes and files in selected local folders",
        command: "npx",
        args: "-y @modelcontextprotocol/server-filesystem",
        requiresFolder: true,
        requiresApiKey: false,
        envKey: nil
    ),
    MCPPresetTemplate(
        id: "fetch",
        name: "🌐 Web Content Fetcher (Fetch)",
        iconName: "globe",
        description: "Enable AI to directly fetch HTML and Markdown content from the web",
        command: "npx",
        args: "-y @modelcontextprotocol/server-fetch",
        requiresFolder: false,
        requiresApiKey: false,
        envKey: nil
    ),
    MCPPresetTemplate(
        id: "puppeteer",
        name: "🖥️ Browser Rendering (Puppeteer)",
        iconName: "display",
        description: "Render dynamic web pages and execute actions using a headless browser",
        command: "npx",
        args: "-y @modelcontextprotocol/server-puppeteer",
        requiresFolder: false,
        requiresApiKey: false,
        envKey: nil
    ),
    MCPPresetTemplate(
        id: "brave",
        name: "🔍 Brave Web Search (Brave)",
        iconName: "magnifyingglass",
        description: "Equip AI with real-time web search capabilities using Brave Search API",
        command: "npx",
        args: "-y @modelcontextprotocol/server-brave-search",
        requiresFolder: false,
        requiresApiKey: true,
        envKey: "BRAVE_API_KEY"
    ),
    MCPPresetTemplate(
        id: "github",
        name: "🐙 GitHub Integration (GitHub)",
        iconName: "chevron.left.forwardslash.chevron.right",
        description: "Search GitHub repositories, code files, issues, and pull requests",
        command: "npx",
        args: "-y @modelcontextprotocol/server-github",
        requiresFolder: false,
        requiresApiKey: true,
        envKey: "GITHUB_PERSONAL_ACCESS_TOKEN"
    )
]

struct MCPSettingsView: View {
    @State private var servers: [MCPServerConfig] = []
    @State private var showingAddSheet: Bool = false

    // Sheet Mode
    @State private var addMode: Int = 0 // 0: Preset Gallery, 1: Custom Command

    // Form inputs
    @State private var selectedPresetId: String = mcpPresets[0].id
    @State private var newServerName: String = ""
    @State private var selectedFolderPath: String = ""
    @State private var apiKeyInput: String = ""

    // Custom mode inputs
    @State private var customCommand: String = "npx"
    @State private var customArgs: String = ""

    private var selectedPreset: MCPPresetTemplate {
        mcpPresets.first(where: { $0.id == selectedPresetId }) ?? mcpPresets[0]
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey("💡 What is MCP? Model Context Protocol (MCP) is an open plugin standard that lets local LLMs securely access local files, web scraping tools, or external APIs."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            if servers.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text(LocalizedStringKey("No MCP servers configured yet."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Button {
                        openAddSheet()
                    } label: {
                        Label(LocalizedStringKey("Add Recommended MCP Extension"), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                ForEach(servers) { server in
                    serverRow(server)
                }
            }
        } header: {
            HStack {
                Label(LocalizedStringKey("MCP Servers"), systemImage: "network")
                Spacer()
                Button(LocalizedStringKey("Add Server")) {
                    openAddSheet()
                }
                .font(.system(size: 11))
            }
        } footer: {
            Text(LocalizedStringKey("Configurations are saved to ~/Library/Application Support/MDWriter/mcp.json"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .onAppear {
            loadConfig()
        }
        .sheet(isPresented: $showingAddSheet) {
            addServerSheet
        }
    }

    private func serverRow(_ server: MCPServerConfig) -> some View {
        let status = MCPClientManager.shared.statuses.first(where: { $0.name == server.name })

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(status?.isConnected == true ? Color.green : Color.red)
                        .frame(width: 7, height: 7)

                    Text(server.name)
                        .font(.system(size: 13, weight: .semibold))

                    if let count = status?.toolCount, count > 0 {
                        Text("(\(count) tools)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(server.command) \((server.args ?? []).joined(separator: " "))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let err = status?.errorMessage {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Button {
                if let idx = servers.firstIndex(where: { $0.name == server.name }) {
                    servers.remove(at: idx)
                    saveConfig()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var addServerSheet: some View {
        VStack(spacing: 16) {
            Text(LocalizedStringKey("Add MCP Extension"))
                .font(.system(size: 15, weight: .bold))

            Picker("", selection: $addMode) {
                Text(LocalizedStringKey("📦 Recommended Presets")).tag(0)
                Text(LocalizedStringKey("⚙️ Custom Command")).tag(1)
            }
            .pickerStyle(.segmented)

            if addMode == 0 {
                presetForm
            } else {
                customForm
            }

            HStack {
                Button(LocalizedStringKey("Cancel")) {
                    showingAddSheet = false
                }
                Spacer()
                Button(LocalizedStringKey("Add & Connect")) {
                    saveNewServer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAddDisabled)
            }
        }
        .padding(20)
        .frame(width: 460, height: 420)
    }

    private var presetForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(LocalizedStringKey("Select Template"), selection: $selectedPresetId) {
                ForEach(mcpPresets) { preset in
                    Text(LocalizedStringKey(preset.name)).tag(preset.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedPresetId) { _, newId in
                if let found = mcpPresets.first(where: { $0.id == newId }) {
                    newServerName = found.id.capitalized
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(selectedPreset.description))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)

            TextField(LocalizedStringKey("Server Name"), text: $newServerName)

            if selectedPreset.requiresFolder {
                HStack {
                    TextField(LocalizedStringKey("Target Folder Path"), text: $selectedFolderPath)
                        .font(.system(size: 11, design: .monospaced))

                    Button(LocalizedStringKey("Browse...")) {
                        selectFolder { path in
                            selectedFolderPath = path
                        }
                    }
                }
            }

            if selectedPreset.requiresApiKey, let envKey = selectedPreset.envKey {
                SecureField(LocalizedStringKey(envKey), text: $apiKeyInput)
                    .font(.system(size: 11, design: .monospaced))
            }
        }
    }

    private var customForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(LocalizedStringKey("Server Name"), text: $newServerName)
            TextField(LocalizedStringKey("Executable Command (e.g. npx / uvx)"), text: $customCommand)
            TextField(LocalizedStringKey("Arguments (space separated)"), text: $customArgs)
        }
    }

    private var isAddDisabled: Bool {
        if newServerName.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if addMode == 0 {
            if selectedPreset.requiresFolder && selectedFolderPath.isEmpty { return true }
            if selectedPreset.requiresApiKey && apiKeyInput.isEmpty { return true }
        } else {
            if customCommand.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        }
        return false
    }

    private func openAddSheet() {
        selectedPresetId = mcpPresets[0].id
        newServerName = "Filesystem"
        selectedFolderPath = NSHomeDirectory() + "/Documents"
        apiKeyInput = ""
        customCommand = "npx"
        customArgs = ""
        addMode = 0
        showingAddSheet = true
    }

    private func saveNewServer() {
        var command = ""
        var argsList: [String] = []
        var envDict: [String: String]? = nil

        if addMode == 0 {
            command = selectedPreset.command
            var rawArgs = selectedPreset.args.split(separator: " ").map(String.init)
            if selectedPreset.requiresFolder {
                rawArgs.append(selectedFolderPath)
            }
            argsList = rawArgs

            if selectedPreset.requiresApiKey, let envKey = selectedPreset.envKey, !apiKeyInput.isEmpty {
                envDict = [envKey: apiKeyInput]
            }
        } else {
            command = customCommand
            argsList = customArgs.split(separator: " ").map(String.init)
        }

        let config = MCPServerConfig(name: newServerName, command: command, args: argsList, env: envDict)
        servers.append(config)
        saveConfig()
        showingAddSheet = false
    }

    private func selectFolder(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Select Folder")
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }

    private func loadConfig() {
        self.servers = MCPConfigurationManager.shared.loadConfig()
    }

    private func saveConfig() {
        try? MCPConfigurationManager.shared.saveConfig(servers: servers)
        Task {
            await MCPClientManager.shared.reloadAndConnectAll()
        }
    }
}
