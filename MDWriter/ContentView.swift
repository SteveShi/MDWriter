//
//  ContentView.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import SwiftUI
import MarkdownUI
import AppKit
import UniformTypeIdentifiers

// 主题枚举
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    
    var paperColor: Color {
        switch self {
        case .light: return Color(red: 0.97, green: 0.97, blue: 0.96)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.11)
        case .system: return Color("PaperColor")
        }
    }
}

extension AppTheme {
    func resolvePaperColor(scheme: ColorScheme) -> Color {
        if self == .system {
            return scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.11) : Color(red: 0.97, green: 0.97, blue: 0.96)
        }
        return paperColor
    }
}

struct ExportItem: Identifiable {
    let id = UUID()
    let content: String
    let contentType: UTType
}

struct ContentView: View {
    @Binding var document: MDWriterDocument
    @State private var headers: [DocumentHeader] = []
    @State private var stats: DocumentStatistics = DocumentStatistics(characters: 0, words: 0, readingTime: 0)
    @State private var showPreview: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showTypographyPanel: Bool = false
    
    // 导出状态
    @State private var exportItem: ExportItem? = nil
    @State private var showExporter: Bool = false
    
    @StateObject private var editorController = EditorController()
    @StateObject private var typographySettings = TypographySettings()
    
    @AppStorage("appTheme") private var currentTheme: AppTheme = .system
    @Environment(\.colorScheme) var systemScheme

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .preferredColorScheme(currentTheme.colorScheme)
        .onAppear {
            updateInfo()
        }
        .toolbar {
            toolbarContent
        }
        .scrollContentBackground(.hidden)
        // 文件导出处理
        .fileExporter(
            isPresented: $showExporter,
            document: TextDocument(exportItem?.content ?? ""),
            contentType: exportItem?.contentType ?? .plainText,
            defaultFilename: "Exported"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
                // 特殊处理 PDF 和 RTF，因为 fileExporter 默认只写文本
                // 如果我们选择的是 PDF/RTF，我们需要重新用 ExportService 生成
                // 但 TextDocument 只能处理纯文本。
                // 修正：我们应该直接使用 NSSavePanel 或者自定义 Document 类型
                // 这里的 fileExporter 对于二进制生成 (PDF) 比较麻烦。
                // 让我们改回在 Action 里直接调用 NSSavePanel 更灵活。
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var sidebarContent: some View {
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
        .listStyle(.sidebar)
        .navigationTitle("Outline")
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var detailContent: some View {
        ZStack(alignment: .bottomTrailing) {
            HSplitView {
                // MARK: - Editor Area
                ZStack {
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
                }
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)

                // MARK: - Preview Area
                if showPreview {
                    ScrollView {
                        Markdown(document.text)
                            .padding(40)
                            .markdownTheme(.docC)
                    }
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }

            // MARK: - Dashboard
            HStack(spacing: 16) {
                // 使用 LocalizedStringKey 进行格式化
                Label(title: { Text("\(stats.words) words") }, icon: { Image(systemName: "doc.text") })
                Label(title: { Text("\(stats.readingTime) min read") }, icon: { Image(systemName: "clock") })
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
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button(action: { showTypographyPanel.toggle() }) {
                Label("Style", systemImage: "textformat.size")
            }
            .popover(isPresented: $showTypographyPanel, arrowEdge: .bottom) {
                TypographyPanel(settings: typographySettings)
            }
            .help("Typography Settings")
            
            Button(action: { withAnimation { showPreview.toggle() } }) {
                Label("Preview", systemImage: showPreview ? "sidebar.right" : "sidebar.right")
                    .foregroundColor(showPreview ? .accentColor : .secondary)
            }
            .help("Toggle Preview")

            Menu {
                Picker("Theme", selection: $currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.rawValue, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
            } label: {
                Label("Theme", systemImage: currentTheme.icon)
            }

            // Export Menu
            Menu {
                Button(action: { export(as: .pdf) }) {
                    Label("PDF", systemImage: "doc.text")
                }
                Button(action: { export(as: .rtf) }) {
                    Label("Rich Text (Word)", systemImage: "doc.richtext")
                }
                Button(action: { export(as: .markdownDocument) }) {
                    Label("Markdown", systemImage: "text.alignleft")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            
            Button(action: insertImage) {
                Label("Insert Image", systemImage: "photo")
            }
        }
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
