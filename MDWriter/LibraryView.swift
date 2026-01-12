//
//  LibraryView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var fileSystem: FileSystemModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText: String = ""
    
    // 重命名状态
    @State private var renamingItem: FileItem?
    @State private var newName: String = ""
    @State private var isRenaming: Bool = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 第一栏：文件夹列表 (层级结构)
            List(selection: $fileSystem.selectedFolder) {
                Section("Library") {
                    Label("All Documents", systemImage: "tray.full")
                        .tag(fileSystem.rootURL)
                }
                
                Section("Folders") {
                    // 使用 OutlineGroup 展示层级 (如果 FileItem 遵循 Identifiable 且有 children)
                    OutlineGroup(fileSystem.items, children: \.children) { item in
                        Label(item.name, systemImage: "folder")
                            .contextMenu {
                                Button("Rename") { startRenaming(item) }
                                Button("Delete", role: .destructive) { fileSystem.deleteItem(item) }
                                Button("New Group inside") { fileSystem.createNewFolder(in: item.url) }
                            }
                            .tag(item.url)
                    }
                }
            }
            .listStyle(.sidebar)
            // 移除系统标题和工具栏，改用自定义 Header 以实现视觉分离
            .alert("Rename", isPresented: $isRenaming) {
                TextField("New Name", text: $newName)
                Button("Rename") {
                    if let item = renamingItem {
                        fileSystem.renameItem(item, to: newName)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            // 1. Sidebar Custom Header
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("Library")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        if let selected = fileSystem.selectedFolder {
                            fileSystem.createNewFolder(in: selected)
                        }
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .help("New Group")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .overlay(Divider(), alignment: .bottom)
            }
        } content: {
            // 第二栏：文件列表
            VStack(spacing: 0) {
                // 2. Content Custom Header
                HStack {
                    Text(fileSystem.selectedFolder?.lastPathComponent ?? "Files")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        if let folder = fileSystem.selectedFolder {
                            fileSystem.createNewFile(in: folder)
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                    .disabled(fileSystem.selectedFolder == nil)
                    .help("New Note")
                    .foregroundColor(fileSystem.selectedFolder == nil ? .secondary.opacity(0.3) : .primary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .overlay(Divider(), alignment: .bottom)

                if let selectedFolder = fileSystem.selectedFolder {
                    let files = fileSystem.files(in: selectedFolder).filter {
                        searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    List(selection: $fileSystem.selectedFile) {
                        ForEach(files) { file in
                            FileRowView(file: file, preview: fileSystem.readFile(file.url))
                                .tag(file.url)
                                .contextMenu {
                                    Button("Rename", systemImage: "pencil") { startRenaming(file) }
                                    Button("Delete", systemImage: "trash", role: .destructive) { fileSystem.deleteItem(file) }
                                }
                        }
                    }
                    .listStyle(.inset)
                    .searchable(text: $searchText, placement: .sidebar)
                } else {
                    // 空状态占位
                    Text("Select a folder")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor))
                }
            }
        } detail: {
            // 第三栏：编辑器 + 分割线
            HStack(spacing: 0) {
                // 3. 永久存在的分割线
                Divider()
                    .ignoresSafeArea()
                
                Group {
                    if let selectedFile = fileSystem.selectedFile {
                        EditorWrapper(fileURL: selectedFile)
                            .id(selectedFile)
                    } else {
                        ContentUnavailableView("No Selection", systemImage: "doc.text", description: Text("Select a document to start writing."))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(nsColor: .windowBackgroundColor))
                    }
                }
            }
        }
    }
    
    private func startRenaming(_ item: FileItem) {
        renamingItem = item
        newName = item.name.replacingOccurrences(of: ".md", with: "")
        isRenaming = true
    }
}

// 独立的行视图，用于显示标题和摘要
struct FileRowView: View {
    let file: FileItem
    let preview: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file.name.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: ".markdown", with: ""))
                .font(.headline)
                .lineLimit(1)
            
            // 提取摘要：去掉标题符号，取前两行
            Text(summary(from: preview))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxHeight: 35, alignment: .topLeading)
            
            Text(file.modificationDate, style: .date)
                .font(.caption2)
                .foregroundColor(.tertiaryLabel)
        }
        .padding(.vertical, 4)
    }
    
    private func summary(from text: String) -> String {
        let lines = text.split(separator: "\n")
        let contentLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") }
        return contentLines.prefix(2).joined(separator: " ")
    }
}

extension Color {
    static var tertiaryLabel: Color {
        #if os(macOS)
        return Color(nsColor: .tertiaryLabelColor)
        #else
        return .gray
        #endif
    }
}

// 包装 ContentView 以适配新的 FileSystemModel
struct EditorWrapper: View {
    let fileURL: URL
    @EnvironmentObject var fileSystem: FileSystemModel
    @State private var document: MDWriterDocument
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        let content = (try? String(contentsOf: fileURL)) ?? ""
        _document = State(initialValue: MDWriterDocument(text: content))
    }
    
    var body: some View {
        ContentView(document: $document)
            .onChange(of: document.text) { 
                fileSystem.saveFile(fileURL, content: document.text)
            }
            .onDisappear {
                fileSystem.saveFile(fileURL, content: document.text)
            }
    }
}

