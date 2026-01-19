//
//  ContentView.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
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
        Group {
            #if os(macOS)
            HSplitView {
                mainEditorArea
                if showOutline && note != nil {
                    outlineView
                        .frame(minWidth: 200, maxWidth: 300, maxHeight: .infinity)
                }
            }
            #else
            mainEditorArea
                .sheet(isPresented: $showOutline) {
                    NavigationStack {
                        dashboardView
                            .navigationTitle(LocalizedStringKey("Dashboard"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(LocalizedStringKey("Done")) { showOutline = false }
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                }
            #endif
        }
        .preferredColorScheme(currentTheme.colorScheme)
        #if os(macOS)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarRole(.editor)
        #endif
        .onAppear {
            updateInfo()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 20) {
                    // 1. 导出
                    Button(action: { export(as: .pdf) }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    // 2. 仪表盘 (Outline + Stats)
                    Button(action: { withAnimation { showOutline.toggle() } }) {
                        Image(systemName: "gauge.with.needle")
                    }
                }
            }
            #endif
            
            ToolbarItemGroup(placement: .primaryAction) {
                #if os(macOS)
                // 1. 字体选择 (Aa)
                Button(action: { showFontSettings = true }) {
                    Image(systemName: "textformat")
                        .font(.system(size: 18))
                }
                .popover(isPresented: $showFontSettings) {
                    fontSettingsView
                }
                #else
                Button(action: { showFontSettings = true }) {
                    Image(systemName: "textformat")
                        .font(.system(size: 18))
                }
                .sheet(isPresented: $showFontSettings) {
                    NavigationStack {
                        fontSettingsView
                            .navigationTitle(LocalizedStringKey("Format"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(LocalizedStringKey("Done")) { showFontSettings = false }
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                }
                .disabled(note == nil)
                #endif

                // 2. 插入图片
                #if os(macOS)
                Button(action: insertImage) {
                    Image(systemName: "paperclip")
                }
                .disabled(note == nil)
                #endif

                // 3. 主题选择
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

                // 4. 导出
                Menu {
                    Button(action: { showExportPreview = true }) {
                        Label(LocalizedStringKey("PDF"), systemImage: "doc.text")
                    }
                    #if os(macOS)
                    Button(action: { export(as: .rtf) }) {
                        Label(LocalizedStringKey("Rich Text (Word)"), systemImage: "doc.richtext")
                    }
                    #endif
                    Button(action: { export(as: .markdownDocument) }) {
                        Label(LocalizedStringKey("Markdown"), systemImage: "text.alignleft")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(note == nil)

                #if os(macOS)
                // 5. 搜索
                searchButton
                
                // 6. 大纲 (macOS)
                Button(action: { withAnimation { showOutline.toggle() } }) {
                    Image(systemName: "list.bullet.indent")
                        .foregroundColor(showOutline ? .accentColor : .secondary)
                }
                .disabled(note == nil)
                #endif
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
        #if os(iOS)
        .sheet(isPresented: $showExporter) {
            if let item = exportItem {
                ShareSheet(activityItems: [item.content])
            }
        }
        #endif
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mainEditorArea: some View {
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
                
                // Ulysses-style Bottom Toolbar
                #if os(macOS)
                VStack {
                    Spacer()
                    UlyssesBottomToolbar(controller: editorController)
                }
                #endif
            } else {
                ContentUnavailableView {
                    Label(LocalizedStringKey("No Selection"), systemImage: "doc.text")
                } description: {
                    Text(LocalizedStringKey("Select a document to start writing."))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var searchButton: some View {
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
    }
    #endif

    @ViewBuilder
    private var dashboardView: some View {
        List {
            Section(LocalizedStringKey("Statistics")) {
                HStack {
                    Label(LocalizedStringKey("Characters"), systemImage: "text.cursor")
                    Spacer()
                    Text("\(stats.characters)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label(LocalizedStringKey("Words"), systemImage: "text.word.spacing")
                    Spacer()
                    Text("\(stats.words)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Label(LocalizedStringKey("Reading Time"), systemImage: "clock")
                    Spacer()
                    Text("\(stats.readingTime) min")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(LocalizedStringKey("Outline")) {
                if headers.isEmpty {
                    Text(LocalizedStringKey("No headings found"))
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(headers) { header in
                        HStack {
                            Spacer().frame(width: CGFloat(header.level - 1) * 12)
                            Text(header.title)
                                .font(.system(.subheadline, design: .rounded))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fontSettingsView: some View {
        Form {
            Section(LocalizedStringKey("Font")) {
                Picker(LocalizedStringKey("Family"), selection: $editorSettings.fontName) {
                    Text(LocalizedStringKey("System Font")).tag("System")
                    #if os(macOS)
                    Divider()
                    ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { font in
                        Text(font).tag(font)
                    }
                    #endif
                }
                #if !os(macOS)
                .pickerStyle(.navigationLink)
                #endif
            }

            Section(LocalizedStringKey("Paragraph")) {
                HStack {
                    Label(LocalizedStringKey("Line Height"), systemImage: "line.horizontal.3")
                    Spacer()
                    Stepper(String(format: "%.1f", editorSettings.lineHeightMultiple), value: $editorSettings.lineHeightMultiple, in: 1.0...3.0, step: 0.1)
                }

                HStack {
                    Label(LocalizedStringKey("Line Width"), systemImage: "arrow.left.and.right")
                    Spacer()
                    #if os(macOS)
                    Slider(value: $editorSettings.contentWidth, in: 400...1200, step: 50)
                    #else
                    Stepper("\(Int(editorSettings.contentWidth))", value: $editorSettings.contentWidth, in: 300...1000, step: 50)
                    #endif
                }
            }

            Section {
                Toggle(LocalizedStringKey("Typewriter Mode"), isOn: $editorSettings.typewriterMode)
            }
        }
        #if os(macOS)
        .padding()
        .frame(width: 280)
        #endif
    }

    @ViewBuilder
    private var outlineView: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("Outline"))
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
        .background(Color.platformBackground)
    }

    // MARK: - Actions

    private func insertImage() {
        #if os(macOS)
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
        #endif
    }

    private func export(as type: UTType) {
        #if os(macOS)
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
        #else
        // iOS 导出逻辑（通常使用 ShareSheet）
        if let note = note {
            let item = ExportItem(content: note.content, contentType: type)
            self.exportItem = item
            self.showExporter = true
        }
        #endif
    }

    private func updateInfo() {
        guard let content = note?.content else {
            self.headers = []
            self.stats = DocumentStatistics(characters: 0, words: 0, readingTime: 0)
            return
        }

        Task {
            let newHeaders = MDHeaderParser.parseHeaders(from: content)
            let newStats = DocumentStatistics.calculate(from: content)
            self.headers = newHeaders
            self.stats = newStats
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

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif