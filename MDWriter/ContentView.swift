//
//  ContentView.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import AppKit
import MDEditor
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ExportItem: Identifiable {
    let id = UUID()
    let content: String
    let contentType: UTType
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var autosaveTask: Task<Void, Never>? = nil

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
                    MDEditorView(
                        text: $bindableNote.content,
                        configuration: editorSettings.configuration,
                        proxy: editorController.proxy
                    )
                    // 强制 SwiftUI 在文档切换或配置变化时重启视图，确保状态干净且不串场
                    .id("\(note.persistentModelID)\(editorSettings.configuration)")
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

                        // 更新修改时间并触发自动保存
                        note.modifiedAt = Date()
                        scheduleAutoSave()
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

                // Top Gradient Fade
                if note != nil {
                    VStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                currentTheme.paperColor, currentTheme.paperColor.opacity(0),
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                        .ignoresSafeArea(.all, edges: .top)

                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                // Ulysses-style Context-Sensitive Markup Bar
                if note != nil {
                    VStack(spacing: 0) {
                        Spacer()

                        UlyssesMarkupBar(controller: editorController)
                            .background(currentTheme.paperColor)  // Ensure solid background behind bar
                    }
                }

                // MARK: - Find & Replace Overlay
                if editorController.isSearchVisible {
                    VStack {
                        UlyssesSearchBar(controller: editorController)
                            .padding(.top, 50)  // Pin to top but below title bar
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .zIndex(100)
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - Pane 2: Right Sidebar (Dashboard)
            if showOutline, let currentNote = note {
                DashboardView(
                    note: currentNote,
                    text: Binding(
                        get: { currentNote.content },
                        set: { currentNote.content = $0 }
                    )
                )
                .frame(minWidth: 240, maxWidth: 300, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarRole(.editor)  // 关键：确保编辑器工具栏在窗口最右侧
        .onAppear {
            updateInfo()
        }
        .onDisappear {
            flushAutoSave()
        }
        .onChange(of: note?.persistentModelID) { _, _ in
            flushAutoSave()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                flushAutoSave()
            }
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

                // 5. 搜索 (Internal Editor Search)
                Button(action: {
                    withAnimation(.spring()) {
                        editorController.isSearchVisible.toggle()
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(editorController.isSearchVisible ? .accentColor : .primary)
                }
                .disabled(note == nil)
                .help(LocalizedStringKey("Find and Replace"))

                // 6. 大纲 (Dashboard toggle)
                Button(action: { withAnimation { showOutline.toggle() } }) {
                    Image(systemName: "sidebar.right")  // More appropriate icon for dashboard
                        .foregroundColor(showOutline ? .accentColor : .secondary)
                }
                .disabled(note == nil)
                .help(LocalizedStringKey("Dashboard"))
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
        .onReceive(NotificationCenter.default.publisher(for: .showFind)) { _ in
            withAnimation(.spring()) {
                editorController.isSearchVisible = true
                editorController.isReplaceVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFindReplace)) { _ in
            withAnimation(.spring()) {
                editorController.isSearchVisible = true
                editorController.isReplaceVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { _ in
            editorController.findNext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .findPrevious)) { _ in
            editorController.findPrevious()
        }
    }

    private func scheduleAutoSave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            do {
                try modelContext.save()
            } catch {
                print("AutoSave failed: \(error)")
            }
        }
    }

    private func flushAutoSave() {
        autosaveTask?.cancel()
        do {
            try modelContext.save()
        } catch {
            print("AutoSave flush failed: \(error)")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var fontSettingsView: some View {
        VStack(spacing: 12) {
            Picker(LocalizedStringKey("Font:"), selection: $editorSettings.fontName) {
                Text(LocalizedStringKey("System Font")).tag("System")
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
                if let filename = ImageManager.shared.saveImage(from: url) {
                    editorController.insert("![](\(filename))")
                }
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

        Task {
            let newHeaders = MDHeaderParser.parseHeaders(from: content)
            let newStats = DocumentStatistics.calculate(from: content)
            self.headers = newHeaders
            self.stats = newStats
        }
    }
}

// 辅助：用于导出 Markdown 包（包含图片）
struct MarkdownPackageDocument: FileDocument {
    var text: String

    init(text: String) {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.folder] }  // 导出为文件夹

    init(configuration: ReadConfiguration) throws {
        self.text = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // 1. 创建根目录 Wrapper
        let rootWrapper = FileWrapper(directoryWithFileWrappers: [:])

        // 2. 处理文本内容，替换图片路径，并收集需要复制的图片
        var processedText = text
        var imagesToCopy: [String] = []

        let pattern = #"!\[(.*?)\]\((.*?)\)"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let matches = regex.matches(
            in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        // 倒序替换以保持 Range 正确
        for match in matches.reversed() {
            let imagePath = nsString.substring(with: match.range(at: 2))
            // 如果是本地文件名 (不包含 / 且不是 http)
            if !imagePath.contains("/") && !imagePath.lowercased().hasPrefix("http") {
                imagesToCopy.append(imagePath)

                // 获取 Alt Text
                let altText = nsString.substring(with: match.range(at: 1))

                // 替换为相对路径
                let replacement = "![\(altText)](images/\(imagePath))"
                if let range = Range(match.range, in: processedText) {
                    processedText.replaceSubrange(range, with: replacement)
                }
            }
        }

        // 3. 添加主文本文件 (index.md)
        if let textData = processedText.data(using: .utf8) {
            let textWrapper = FileWrapper(regularFileWithContents: textData)
            textWrapper.preferredFilename = "index.md"
            rootWrapper.addFileWrapper(textWrapper)
        }

        // 4. 创建 images 文件夹并复制图片
        if !imagesToCopy.isEmpty {
            let imagesDirWrapper = FileWrapper(directoryWithFileWrappers: [:])
            imagesDirWrapper.preferredFilename = "images"

            // 获取 Documents/Images 目录 (手动获取以避免 Actor 隔离问题)
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
            let imagesDirURL = documentsURL?.appendingPathComponent("Images")

            for filename in imagesToCopy {
                if let imagesDirURL = imagesDirURL {
                    let imageURL = imagesDirURL.appendingPathComponent(filename)
                    if let imageData = try? Data(contentsOf: imageURL) {
                        let imageWrapper = FileWrapper(regularFileWithContents: imageData)
                        imageWrapper.preferredFilename = filename
                        imagesDirWrapper.addFileWrapper(imageWrapper)
                    }
                }
            }

            rootWrapper.addFileWrapper(imagesDirWrapper)
        }

        return rootWrapper
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
