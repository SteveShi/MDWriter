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
                Section(LocalizedStringKey("Library")) {
                    Label(LocalizedStringKey("All Documents"), systemImage: "tray.full")
                        .tag(fileSystem.rootURL)
                }
                
                Section(LocalizedStringKey("Folders")) {
                    // 使用 OutlineGroup 展示层级
                    OutlineGroup(fileSystem.items, children: \.children) { item in
                        Label(item.name, systemImage: "folder")
                            .contextMenu {
                                Button { startRenaming(item) } label: { Label(LocalizedStringKey("Rename"), systemImage: "pencil") }
                                Button(role: .destructive) { fileSystem.deleteItem(item) } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                                Button { fileSystem.createNewFolder(in: item.url) } label: { Label(LocalizedStringKey("New Group"), systemImage: "folder.badge.plus") }
                            }
                            .tag(item.url)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(LocalizedStringKey("Library"))
            .alert(LocalizedStringKey("Rename"), isPresented: $isRenaming) {
                TextField(LocalizedStringKey("New Name"), text: $newName)
                Button(LocalizedStringKey("Rename")) {
                    if let item = renamingItem {
                        fileSystem.renameItem(item, to: newName)
                    }
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) {}
            }
            // 1. Sidebar Toolbar
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if let selected = fileSystem.selectedFolder {
                            fileSystem.createNewFolder(in: selected)
                        } else {
                            fileSystem.createNewFolder(in: fileSystem.rootURL)
                        }
                    }) {
                        Label(LocalizedStringKey("New Group"), systemImage: "folder.badge.plus")
                    }
                    .help(LocalizedStringKey("New Group"))
                }
            }
        } content: {
            // 第二栏：文件列表
            Group {
                if let selectedFolder = fileSystem.selectedFolder {
                    let files = fileSystem.files(in: selectedFolder).filter {
                        searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    List(selection: $fileSystem.selectedFile) {
                        ForEach(files) {
                            file in
                            FileRowView(file: file, preview: fileSystem.readFile(file.url))
                                .tag(file.url)
                                .contextMenu {
                                    Button { startRenaming(file) } label: { Label(LocalizedStringKey("Rename"), systemImage: "pencil") }
                                    Button(role: .destructive) { fileSystem.deleteItem(file) } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                                }
                        }
                    }
                    .listStyle(.inset)
                    .searchable(text: $searchText, placement: .sidebar)
                    .navigationTitle(fileSystem.selectedFolder?.lastPathComponent ?? "Files")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: {
                                fileSystem.createNewFile(in: selectedFolder)
                            }) {
                                Label(LocalizedStringKey("New Note"), systemImage: "square.and.pencil")
                            }
                            .help(LocalizedStringKey("New Note"))
                        }
                    }
                } else {
                    // 空状态占位
                    VStack {
                        Spacer()
                        Image(systemName: "folder")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.2))
                        Text(LocalizedStringKey("Select a folder"))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: {}) {
                                Label(LocalizedStringKey("New Note"), systemImage: "square.and.pencil")
                            }
                            .disabled(true)
                        }
                    }
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
                    } else {
                        ContentUnavailableView {
                            Label(LocalizedStringKey("No Selection"), systemImage: "doc.text")
                        } description: {
                            Text(LocalizedStringKey("Select a document to start writing."))
                        }
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
            
            // 提取摘要
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

// 包装 ContentView
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
            .onChange(of: fileURL) { newURL in
                loadContent(from: newURL)
            }
            .onChange(of: document.text) { 
                fileSystem.saveFile(fileURL, content: document.text)
            }
            .onDisappear {
                fileSystem.saveFile(fileURL, content: document.text)
            }
    }
    
    private func loadContent(from url: URL) {
        let content = (try? String(contentsOf: url)) ?? ""
        self.document = MDWriterDocument(text: content)
    }
}