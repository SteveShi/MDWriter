//
//  AISettingsView.swift
//  MDWriter
//
//  Comprehensive AI, Local LLM, MCP, and Web Search settings panel.
//

import SwiftUI

struct AISettingsView: View {
    @AppStorage("aiEnabled") private var aiEnabled: Bool = true
    @AppStorage("aiTranslationTarget") private var translationTarget: String = "auto"
    @AppStorage("llmEnabled") private var llmEnabled: Bool = true
    @AppStorage("llmProvider") private var providerRaw: String = LLMProvider.ollama.rawValue
    @AppStorage("llmCustomBaseURL") private var customBaseURL: String = LLMProvider.ollama.defaultBaseURL
    @AppStorage("llmSelectedModel") private var selectedModel: String = ""

    @AppStorage("aiContextLevel") private var contextLevelRaw: String = AIContextLevel.metadata.rawValue
    @AppStorage("aiCustomSystemPrompt") private var customSystemPrompt: String = ""

    // Web Search Options
    @AppStorage("searchEnabled") private var searchEnabled: Bool = true
    @AppStorage("searchEngine") private var searchEngineRaw: String = WebSearchEngineProvider.duckDuckGo.rawValue
    @AppStorage("searchCustomURL") private var searchCustomURL: String = ""
    @AppStorage("searchBraveKey") private var searchBraveKey: String = ""
    @AppStorage("searchTavilyKey") private var searchTavilyKey: String = ""
    @AppStorage("searchExaKey") private var searchExaKey: String = ""
    @AppStorage("searchGoogleKey") private var searchGoogleKey: String = ""
    @AppStorage("searchGoogleCX") private var searchGoogleCX: String = ""
    @AppStorage("searchBingKey") private var searchBingKey: String = ""

    @State private var llmService = LLMService()
    @State private var isDetecting: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Form {
                // Section 1: Apple Intelligence
                Section {
                    Toggle(LocalizedStringKey("Enable On-Device Apple Intelligence"), isOn: $aiEnabled)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Apple Intelligence provides lightweight on-device summary, title generation, and auto-tagging. Zero data leaves your device."))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Picker(LocalizedStringKey("Translation Target Language"), selection: $translationTarget) {
                        Text(LocalizedStringKey("Auto Detect")).tag("auto")
                        Divider()
                        Text("English").tag("en")
                        Text("简体中文").tag("zh-Hans")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Label(LocalizedStringKey("Apple Intelligence"), systemImage: "apple.intelligence")
                }

                // Section 2: Local LLM Engines
                Section {
                    Toggle(LocalizedStringKey("Enable Local LLM Engine"), isOn: $llmEnabled)

                    if llmEnabled {
                        Picker(LocalizedStringKey("Engine Provider"), selection: $providerRaw) {
                            ForEach(LLMProvider.allCases) { provider in
                                Label(provider.displayName, systemImage: provider.iconName)
                                    .tag(provider.rawValue)
                            }
                        }
                        .onChange(of: providerRaw) { _, newRaw in
                            if let provider = LLMProvider(rawValue: newRaw) {
                                customBaseURL = provider.defaultBaseURL
                                Task { await llmService.fetchAvailableModels() }
                            }
                        }

                        HStack {
                            TextField(LocalizedStringKey("Server Base URL"), text: $customBaseURL)
                                .font(.system(size: 12, design: .monospaced))

                            Button {
                                isDetecting = true
                                Task {
                                    _ = await llmService.config.autoDetectProvider()
                                    await llmService.fetchAvailableModels()
                                    isDetecting = false
                                }
                            } label: {
                                if isDetecting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text(LocalizedStringKey("Auto Detect"))
                                }
                            }
                            .disabled(isDetecting)
                        }

                        HStack {
                            Picker(LocalizedStringKey("Active Model"), selection: $selectedModel) {
                                if llmService.availableModels.isEmpty {
                                    Text(selectedModel.isEmpty ? LocalizedStringKey("No models found") : LocalizedStringKey(selectedModel))
                                        .tag(selectedModel)
                                } else {
                                    ForEach(llmService.availableModels) { model in
                                        Text(model.id).tag(model.id)
                                    }
                                }
                            }
                            .pickerStyle(.menu)

                            Button {
                                Task { await llmService.fetchAvailableModels() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }

                        HStack {
                            Text(LocalizedStringKey("Connection Status"))
                                .font(.system(size: 11))
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(llmService.availableModels.isEmpty ? Color.red : Color.green)
                                    .frame(width: 8, height: 8)
                                Text(llmService.availableModels.isEmpty ? LocalizedStringKey("Disconnected") : LocalizedStringKey("Connected"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label(LocalizedStringKey("Local LLM Engine"), systemImage: "cpu")
                } footer: {
                    Text(LocalizedStringKey("Supports Ollama, LM Studio, oMLX, llama.cpp, MLX, Jan, and custom OpenAI-compatible local endpoints."))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                // Section 3: AI Context & System Prompt
                Section {
                    Picker(LocalizedStringKey("Document Context Level"), selection: $contextLevelRaw) {
                        Text(LocalizedStringKey("Off (No Context)")).tag(AIContextLevel.none.rawValue)
                        Text(LocalizedStringKey("Metadata (Title, Tags, Stats)")).tag(AIContextLevel.metadata.rawValue)
                        Text(LocalizedStringKey("Full Document")).tag(AIContextLevel.full.rawValue)
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(LocalizedStringKey("Custom System Prompt"))
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            if !customSystemPrompt.isEmpty {
                                Button(LocalizedStringKey("Reset")) {
                                    customSystemPrompt = ""
                                }
                                .font(.system(size: 11))
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }

                        TextEditor(text: $customSystemPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 80, maxHeight: 160)
                            .padding(4)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                    }
                } header: {
                    Label(LocalizedStringKey("AI Context & Prompt"), systemImage: "text.badge.plus")
                } footer: {
                    Text(LocalizedStringKey("Custom instructions are appended to the system prompt. LLMs automatically receive document context according to the selected level."))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                // Section 4: MCP Servers
                MCPSettingsView()

                // Section 4: Web Search (Multi-Engine, Cherry Studio inspired)
                Section {
                    Toggle(LocalizedStringKey("Enable Web Search"), isOn: $searchEnabled)

                    if searchEnabled {
                        Picker(LocalizedStringKey("Search Engine"), selection: $searchEngineRaw) {
                            ForEach(WebSearchEngineProvider.allCases) { engine in
                                Text(LocalizedStringKey(engine.displayName)).tag(engine.rawValue)
                            }
                        }
                        .pickerStyle(.menu)

                        let currentEngine = WebSearchEngineProvider(rawValue: searchEngineRaw) ?? .duckDuckGo

                        switch currentEngine {
                        case .duckDuckGo:
                            Text(LocalizedStringKey("Built-in Web Search uses DuckDuckGo HTML by default (Zero API Key, Zero Data Upload)."))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                        case .searxng:
                            HStack {
                                Text(LocalizedStringKey("SearXNG Instance URL"))
                                    .font(.system(size: 11))
                                Spacer()
                                TextField("https://searx.be", text: $searchCustomURL)
                                    .font(.system(size: 12, design: .monospaced))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 240)
                            }

                        case .brave:
                            HStack {
                                Text(LocalizedStringKey("Brave Search API Key"))
                                    .font(.system(size: 11))
                                Spacer()
                                SecureField("BS-xxxxxx", text: $searchBraveKey)
                                    .font(.system(size: 12, design: .monospaced))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 240)
                            }

                        case .tavily:
                            HStack {
                                Text(LocalizedStringKey("Tavily API Key"))
                                    .font(.system(size: 11))
                                Spacer()
                                SecureField("tvly-xxxxxx", text: $searchTavilyKey)
                                    .font(.system(size: 12, design: .monospaced))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 240)
                            }

                        case .exa:
                            HStack {
                                Text(LocalizedStringKey("Exa API Key"))
                                    .font(.system(size: 11))
                                Spacer()
                                SecureField("exa-xxxxxx", text: $searchExaKey)
                                    .font(.system(size: 12, design: .monospaced))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 240)
                            }

                        case .google:
                            VStack(spacing: 8) {
                                HStack {
                                    Text(LocalizedStringKey("Google API Key"))
                                        .font(.system(size: 11))
                                    Spacer()
                                    SecureField("AIzaSy-xxxxxx", text: $searchGoogleKey)
                                        .font(.system(size: 12, design: .monospaced))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 240)
                                }
                                HStack {
                                    Text(LocalizedStringKey("Google Engine ID (CX)"))
                                        .font(.system(size: 11))
                                    Spacer()
                                    TextField("0123456789...", text: $searchGoogleCX)
                                        .font(.system(size: 12, design: .monospaced))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 240)
                                }
                            }

                        case .bing:
                            HStack {
                                Text(LocalizedStringKey("Bing Search API Key"))
                                    .font(.system(size: 11))
                                Spacer()
                                SecureField("bing-key-xxxxxx", text: $searchBingKey)
                                    .font(.system(size: 12, design: .monospaced))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 240)
                            }
                        }
                    }
                } header: {
                    Label(LocalizedStringKey("Web Search"), systemImage: "magnifyingglass")
                } footer: {
                    Text(LocalizedStringKey("Built-in Web Search allows local LLMs to fetch live information directly without uploading personal documents."))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.vertical, 8)
        }
        .onAppear {
            Task {
                await llmService.fetchAvailableModels()
            }
        }
    }
}
