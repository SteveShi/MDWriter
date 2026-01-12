//
//  ContentView.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import AppKit
import MarkdownUI
import SwiftUI
import UniformTypeIdentifiers

struct ExportItem: Identifiable {
    let id = UUID()
    let content: String
    let contentType: UTType
}

struct ContentView: View {
    @Binding var document: MDWriterDocument
    @State private var headers: [DocumentHeader] = []
    @State private var stats: DocumentStatistics = DocumentStatistics(
        characters: 0, words: 0, readingTime: 0)

    // Search Bindings
    @Binding var searchText: String
    @Binding var isSearching: Bool

    // View states (synced with menu commands)
    @Binding var showPreview: Bool
    @Binding var showOutline: Bool
    @Binding var textZoom: CGFloat

    // UI 状态 (local only)
    @State private var showTypographyPanel: Bool = false
    @State private var showShortcutsSheet: Bool = false

    // 导出状态
    @State private var exportItem: ExportItem? = nil
    @State private var showExporter: Bool = false

    @StateObject private var editorController = EditorController()
    @StateObject private var typographySettings = TypographySettings()

    @AppStorage("appTheme") private var currentTheme: AppTheme = .system
    @AppStorage("showDashboard") private var showDashboard: Bool = false
    @Environment(\.colorScheme) var systemScheme

    // Animation namespace

    // Animation namespace
    @Namespace private var animation

    var body: some View {
        HSplitView {
            // MARK: - Pane 1: Editor Area (with Search & Dashboard)
            ZStack(alignment: .topTrailing) {
                currentTheme.resolvePaperColor(scheme: systemScheme == .dark ? .dark : .light)
                    .ignoresSafeArea()

                MacEditorView(
                    text: $document.text,
                    configuration: typographySettings.configuration,
                    controller: editorController
                )
                .onChange(of: document.text) {
                    updateInfo()
                }

                // Dashboard (Counter) - Attached to Editor Pane

                // Dashboard (Counter) - Attached to Editor Pane
                // Positioned at Bottom Center of THIS pane
                if showDashboard {
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            Label(
                                title: { Text("\(stats.words) words") },
                                icon: { Image(systemName: "doc.text") })
                            Label(
                                title: { Text("\(stats.readingTime) min read") },
                                icon: { Image(systemName: "clock") })
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(20)
                        .opacity(0.8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Pane 2: Preview Area (Conditional)
            if showPreview {
                ScrollView {
                    Markdown(document.text)
                        .padding(40)
                        .markdownTheme(.docC)
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            // MARK: - Pane 3: Right Sidebar (Outline)
            if showOutline {
                outlineView
                    .frame(minWidth: 200, maxWidth: 300, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .onAppear {
            updateInfo()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Search
                if isSearching {
                    HStack {
                        TextField(LocalizedStringKey("Search"), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)

                        Button(action: {
                            withAnimation {
                                isSearching = false
                                searchText = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        withAnimation {
                            isSearching = true
                        }
                    }) {
                        Label(LocalizedStringKey("Search"), systemImage: "magnifyingglass")
                    }
                    .help(LocalizedStringKey("Search"))
                }

                // Style
                Button(action: { showTypographyPanel.toggle() }) {
                    Label(LocalizedStringKey("Style"), systemImage: "textformat.size")
                }
                .popover(isPresented: $showTypographyPanel, arrowEdge: .bottom) {
                    TypographyPanel(settings: typographySettings)
                }
                .help(LocalizedStringKey("Typography Settings"))

                // Preview
                Button(action: { withAnimation { showPreview.toggle() } }) {
                    Label(LocalizedStringKey("Preview"), systemImage: "eye")
                        .foregroundColor(showPreview ? .accentColor : .secondary)
                }
                .help(LocalizedStringKey("Toggle Preview"))

                // Outline (使用 sidebar.right 图标)
                Button(action: { withAnimation { showOutline.toggle() } }) {
                    Label(LocalizedStringKey("Outline"), systemImage: "sidebar.right")
                        .foregroundColor(showOutline ? .accentColor : .secondary)
                }
                .help(LocalizedStringKey("Toggle Outline"))

                // Theme
                Menu {
                    Button(action: { currentTheme = .system }) {
                        Label(LocalizedStringKey("System"), systemImage: "gear")
                    }
                    Button(action: { currentTheme = .light }) {
                        Label(LocalizedStringKey("Light"), systemImage: "sun.max")
                    }
                    Button(action: { currentTheme = .dark }) {
                        Label(LocalizedStringKey("Dark"), systemImage: "moon")
                    }
                } label: {
                    Label(LocalizedStringKey("Theme"), systemImage: currentTheme.icon)
                }
                .help(LocalizedStringKey("Theme Selection"))

                // Export
                Menu {
                    Button(action: { export(as: .pdf) }) {
                        Label(LocalizedStringKey("PDF"), systemImage: "doc.text")
                    }
                    Button(action: { export(as: .rtf) }) {
                        Label(LocalizedStringKey("Rich Text (Word)"), systemImage: "doc.richtext")
                    }
                    Button(action: { export(as: .markdownDocument) }) {
                        Label(LocalizedStringKey("Markdown"), systemImage: "text.alignleft")
                    }
                } label: {
                    Label(LocalizedStringKey("Export"), systemImage: "square.and.arrow.up")
                }
                .help(LocalizedStringKey("Export Document"))

                // Insert Image
                Button(action: insertImage) {
                    Label(LocalizedStringKey("Insert Image"), systemImage: "photo")
                }
                .help(LocalizedStringKey("Insert Image"))
            }
        }
        .sheet(isPresented: $showShortcutsSheet) {
            KeyboardShortcutsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
            showShortcutsSheet = true
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var outlineView: some View {
        VStack(alignment: .leading) {
            Text("Outline")
                .font(.headline)
                .padding()

            List(headers, selection: .constant(nil as DocumentHeader.ID?)) { header in
                HStack {
                    Spacer().frame(width: CGFloat(header.level - 1) * 12)

                    if header.level == 1 {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Circle()
                            .fill(.tertiary)
                            .frame(width: 4, height: 4)
                    }

                    Text(header.title)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineLimit(1)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .padding(.vertical, 2)
            }
            .listStyle(.plain)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func insertImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let imageMarkdown = "![Image](\(url.path))"
                editorController.insert(imageMarkdown)
            }
        }
    }

    private func export(as type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "Untitled"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try ExportService.shared.export(text: document.text, to: url, format: type)
                } catch {
                    print("Export Error: \(error.localizedDescription)")
                    // 在实际应用中，这里可以弹出一个 Alert
                }
            }
        }
    }

    private func updateInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let newHeaders = MDHeaderParser.parseHeaders(from: document.text)
            let newStats = DocumentStatistics.calculate(from: document.text)
            DispatchQueue.main.async {
                self.headers = newHeaders
                self.stats = newStats
            }
        }
    }
}

// 辅助：用于 fileExporter 的简单文档封装 (虽然我们最后用了 NSSavePanel，但留着以备不时之需)
struct TextDocument: FileDocument {
    var text: String
    init(_ text: String) { self.text = text }
    static var readableContentTypes: [UTType] { [.plainText] }
    init(configuration: ReadConfiguration) throws { text = "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: text.data(using: .utf8)!)
    }
}
