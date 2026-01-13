//
//  ContentView.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ExportItem: Identifiable {
    let id = UUID()
    let content: String
    let contentType: UTType
}

struct ContentView: View {
    var note: Note?
    @State private var headers: [DocumentHeader] = []
    @State private var stats: DocumentStatistics = DocumentStatistics(
        characters: 0, words: 0, readingTime: 0)

    // Search Bindings
    @Binding var searchText: String
    @Binding var isSearching: Bool

    // View states (synced with menu commands)
    @Binding var showOutline: Bool
    @Binding var textZoom: CGFloat

    // UI 状态 (local only)
    @State private var showShortcutsSheet: Bool = false
    @State private var showFontSettings: Bool = false

    // 导出状态
    @State private var exportItem: ExportItem? = nil
    @State private var showExporter: Bool = false
    @State private var showExportPreview: Bool = false

    @StateObject private var editorController = EditorController()
    @ObservedObject private var editorSettings = EditorSettings.shared

    @AppStorage("appTheme") private var currentTheme: AppTheme = .light
    @AppStorage("showDashboard") private var showDashboard: Bool = false
    @AppStorage("markdownTheme") private var markdownTheme: MarkdownTheme = .pure
    @Environment(\.colorScheme) var systemScheme

    // Animation namespace
    @Namespace private var animation

    var body: some View {
        HSplitView {
            // MARK: - Pane 1: Editor Area
            ZStack(alignment: .topTrailing) {
                currentTheme.paperColor
                    .ignoresSafeArea()

                if let note = note {
                    @Bindable var bindableNote = note
                    UlyssesEditor(
                        text: $bindableNote.content,
                        noteID: note.persistentModelID,
                        configuration: editorSettings.configuration,
                        controller: editorController
                    )
                    .ignoresSafeArea()
                    .onChange(of: note.content) { oldValue, newValue in
                        updateInfo()

                        // Auto-update title from first line
                        let lines = newValue.components(separatedBy: .newlines)
                        if let firstLine = lines.first,
                            !firstLine.trimmingCharacters(in: .whitespaces).isEmpty
                        {
                            // Strip markdown headers (# )
                            let titleText = firstLine.trimmingCharacters(
                                in: CharacterSet(charactersIn: "# ")
                            ).trimmingCharacters(in: .whitespaces)
                            if !titleText.isEmpty && note.title != titleText {
                                note.title = titleText
                            }
                        } else if note.content.isEmpty {
                            note.title = String(localized: "New Note")
                        }
                    }
                } else {
                    // 无选择时的占位符
                    ContentUnavailableView {
                        Label(LocalizedStringKey("No Selection"), systemImage: "doc.text")
                    } description: {
                        Text(LocalizedStringKey("Select a document to start writing."))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Ulysses-style Bottom Toolbar
                if note != nil {
                    VStack {
                        Spacer()
                        UlyssesBottomToolbar(controller: editorController)
                    }
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Pane 2: Right Sidebar (Outline)
            if showOutline && note != nil {
                outlineView
                    .frame(minWidth: 200, maxWidth: 300, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarRole(.editor)  // 关键：确保编辑器工具栏在窗口最右侧
        .onAppear {
            updateInfo()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 1. 字体选择 (Aa) - 文字风格
                Button(action: { showFontSettings = true }) {
                    Text("Aa")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .popover(isPresented: $showFontSettings) {
                    fontSettingsView
                }
                .disabled(note == nil)
                .help(LocalizedStringKey("Font Settings"))

                // 2. 插入图片 (别针)
                Button(action: insertImage) {
                    Image(systemName: "paperclip")
                }
                .disabled(note == nil)
                .help(LocalizedStringKey("Insert Image"))

                // 3. 主题选择 (即使未选文档也可更改 UI)
                Menu {
                    Button(action: { currentTheme = .light }) {
                        Label(LocalizedStringKey("Light"), systemImage: "sun.max")
                    }
                    Button(action: { currentTheme = .dark }) {
                        Label(LocalizedStringKey("Dark"), systemImage: "moon")
                    }
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                }
                .help(LocalizedStringKey("Theme Selection"))

                // 4. 导出
                Menu {
                    Button(action: { showExportPreview = true }) {
                        Label(LocalizedStringKey("PDF"), systemImage: "doc.text")
                    }
                    Button(action: { export(as: .rtf) }) {
                        Label(LocalizedStringKey("Rich Text (Word)"), systemImage: "doc.richtext")
                    }
                    Button(action: { export(as: .markdownDocument) }) {
                        Label(LocalizedStringKey("Markdown"), systemImage: "text.alignleft")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(note == nil)
                .help(LocalizedStringKey("Export Document"))

                // 5. 搜索
                if isSearching {
                    HStack(spacing: 4) {
                        TextField(LocalizedStringKey("Search"), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
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
                    Button(action: { withAnimation { isSearching = true } }) {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(note == nil)
                }

                // 6. 大纲
                Button(action: { withAnimation { showOutline.toggle() } }) {
                    Image(systemName: "list.bullet.indent")
                        .foregroundColor(showOutline ? .accentColor : .secondary)
                }
                .disabled(note == nil)
                .help(LocalizedStringKey("Toggle Outline"))
            }
        }
        .sheet(isPresented: $showShortcutsSheet) {
            KeyboardShortcutsView()
        }
        .sheet(isPresented: $showExportPreview) {
            if let note = note {
                ExportPreviewView(
                    text: note.content, fileName: note.title.isEmpty ? "Untitled" : note.title)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
            showShortcutsSheet = true
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var fontSettingsView: some View {
        VStack(spacing: 12) {
            Picker(LocalizedStringKey("Font:"), selection: $editorSettings.fontName) {
                Text("System Font").tag("System")
                Divider()
                ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text(LocalizedStringKey("Line Height:"))
                Slider(value: $editorSettings.lineHeightMultiple, in: 1.0...3.0, step: 0.1)
                Text(String(format: "%.1f", editorSettings.lineHeightMultiple))
                    .frame(width: 30)
            }

            HStack {
                Text(LocalizedStringKey("Indent:"))
                Slider(value: $editorSettings.firstLineIndent, in: 0...100, step: 5)
                Text("\(Int(editorSettings.firstLineIndent))")
                    .frame(width: 30)
            }

            HStack {
                Text(LocalizedStringKey("Line Width:"))
                Slider(value: $editorSettings.contentWidth, in: 400...1200, step: 50)
                Text("\(Int(editorSettings.contentWidth))")
                    .frame(width: 40)
            }

            Toggle(LocalizedStringKey("Typewriter Mode"), isOn: $editorSettings.typewriterMode)
        }
        .padding()
        .frame(width: 280)
    }

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
        guard note != nil else { return }
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
        guard let note = note else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = note.title

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try ExportService.shared.export(text: note.content, to: url, format: type)
                } catch {
                    print("Export Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func updateInfo() {
        guard let content = note?.content else {
            self.headers = []
            self.stats = DocumentStatistics(characters: 0, words: 0, readingTime: 0)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let newHeaders = MDHeaderParser.parseHeaders(from: content)
            let newStats = DocumentStatistics.calculate(from: content)
            DispatchQueue.main.async {
                self.headers = newHeaders
                self.stats = newStats
            }
        }
    }
}

// 辅助：用于 fileExporter 的简单文档封装
struct TextDocument: FileDocument {
    var text: String
    init(_ text: String) { self.text = text }
    static var readableContentTypes: [UTType] { [.plainText] }
    init(configuration: ReadConfiguration) throws { text = "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: text.data(using: .utf8)!)
    }
}

// Ulysses 风格底部工具栏按钮
struct BottomToolbarButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .regular))
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary.opacity(0.6))
    }
}
