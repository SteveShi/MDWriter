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
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 第一栏：文件夹列表
            List(selection: $fileSystem.selectedFolder) {
                Section("Locations") {
                    Label("Documents", systemImage: "folder")
                        .tag(fileSystem.rootURL)
                }
                
                let subfolders = fileSystem.subfolders(in: fileSystem.rootURL)
                if !subfolders.isEmpty {
                    Section("Folders") {
                        ForEach(subfolders) { folder in
                            Label(folder.name, systemImage: "folder")
                                .tag(folder.url)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Library")
        } content: {
            // 第二栏：文件列表
            Group {
                if let selectedFolder = fileSystem.selectedFolder {
                    let files = fileSystem.files(in: selectedFolder).filter {
                        searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                    
                    List(selection: $fileSystem.selectedFile) {
                        ForEach(files) { file in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name.replacingOccurrences(of: ".md", with: "").replacingOccurrences(of: ".markdown", with: ""))
                                    .font(.headline)
                                Text(file.modificationDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(file.url)
                        }
                    }
                    .searchable(text: $searchText, placement: .sidebar)
                } else {
                    Text("Select a folder")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notes")
        } detail: {
            // 第三栏：编辑器
            if let selectedFile = fileSystem.selectedFile {
                EditorWrapper(fileURL: selectedFile)
                    .id(selectedFile) // 强制刷新
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Select a document to start writing")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
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
