//
//  LibraryView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]
    // 移除 @Query allNotes 以避免一次性加载所有笔记，提高性能。
    // 笔记列表现在由 NoteListView 管理，它使用带谓词的 @Query 按需加载。

    @State private var selectedFolder: Folder?
    @State private var selectedNote: Note?
    @State private var selectionMode: SelectionMode = .all

    enum SelectionMode: Hashable {
        case all
        case inbox
        case trash
        case folder(Folder)
    }

    @SceneStorage("columnVisibility") private var columnVisibilityRaw: String = "all"
    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            #if os(macOS)
            switch columnVisibilityRaw {
            case "all": return .all
            case "doubleColumn": return .doubleColumn
            case "detailOnly": return .detailOnly
            default: return .automatic
            }
            #else
            return .automatic
            #endif
        } set: { newValue in
            #if os(macOS)
            switch newValue {
            case .all: columnVisibilityRaw = "all"
            case .doubleColumn: columnVisibilityRaw = "doubleColumn"
            case .detailOnly: columnVisibilityRaw = "detailOnly"
            default: columnVisibilityRaw = "automatic"
            }
            #endif
        }
    }
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    @AppStorage("showLibrary") private var showLibrary: Bool = true
    @AppStorage("showOutline") private var showOutline: Bool = false
    @AppStorage("textZoom") private var textZoom: Double = 1.0

    @State private var renamingFolder: Folder?
    @State private var renamingNote: Note?
    @State private var newName: String = ""
    @State private var isRenaming: Bool = false
    @State private var showEmptyTrashAlert: Bool = false
    @State private var showSnapshotBrowser: Bool = false
    @AppStorage("appTheme") private var currentTheme: AppTheme = .light
    
    // 跨平台文件操作状态
    @State private var showImportPicker: Bool = false
    @State private var showBackupExporter: Bool = false
    @State private var showBackupImporter: Bool = false
    @State private var backupData: Data?

    @AppStorage("appTheme") private var currentTheme: AppTheme = .light

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            List(selection: $selectionMode) {
                // ... (List 内容保持不变)
            }
            .background(currentTheme.paperColor)
            .scrollContentBackground(.hidden)
            // ... (其他原有修饰符)
        } content: {
            Group {
                NoteListView(...)
                // ...
            }
            .background(currentTheme.paperColor)
            .scrollContentBackground(.hidden)
        } detail: {
            EditorWrapper(...)
        }
        .tint(currentTheme == .dark ? .white : .accentColor) // 统一强调色
        #if os(iOS)
        .toolbarBackground(currentTheme.paperColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.plainText, .text], allowsMultipleSelection: true) { result in
            if let urls = try? result.get() {
                importNotes(from: urls)
            }
        }
        .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [UTType(filenameExtension: "mdwbk")!]) { result in
            if let url = try? result.get(), let data = try? Data(contentsOf: url) {
                try? BackupManager.shared.restoreBackup(from: data, context: modelContext, replaceLibrary: true)
            }
        }
        .fileExporter(isPresented: $showBackupExporter, document: backupData.map { BackupDocument(data: $0) }, contentType: UTType(filenameExtension: "mdwbk")!) { _ in
            backupData = nil
        }
        .onChange(of: showLibrary) { newValue in
            if (newValue && columnVisibility.wrappedValue == .doubleColumn) || (!newValue && columnVisibility.wrappedValue == .all) {
                withAnimation { columnVisibility.wrappedValue = newValue ? .all : .doubleColumn }
            }
        }
        .onChange(of: columnVisibility.wrappedValue) { newValue in 
            let isVisible = (newValue == .all)
            if showLibrary != isVisible {
                showLibrary = isVisible 
            }
        }
        .onAppear {
            // Sync initial state
            if showLibrary {
                columnVisibility.wrappedValue = .all
            } else {
                columnVisibility.wrappedValue = .doubleColumn
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in createNewNote() }
        .onReceive(NotificationCenter.default.publisher(for: .newFolder)) { _ in
            let folder = Folder(name: String(localized: "New Group"))
            if case .folder(let parent) = selectionMode { folder.parent = parent }
            modelContext.insert(folder)
        }
        .alert(isPresented: $showEmptyTrashAlert) {
            Alert(
                title: Text(LocalizedStringKey("Empty Trash")),
                message: Text(
                    LocalizedStringKey(
                        "Are you sure you want to permanently delete all items in the Trash? This action cannot be undone."
                    )),
                primaryButton: .destructive(
                    Text(LocalizedStringKey("Empty Trash")), action: emptyTrash),
                secondaryButton: .cancel()
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .createSnapshot)) { _ in
            if let note = selectedNote {
                let snapshot = Snapshot(content: note.content, note: note)
                modelContext.insert(snapshot)
                try? modelContext.save()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSnapshotBrowser)) { _ in
            print("DEBUG: Received showSnapshotBrowser notification")
            if let note = selectedNote {
                print("DEBUG: Selected note found: \(note.id)")
                showSnapshotBrowser = true
            } else {
                print("DEBUG: No note selected")
            }
        }
        .sheet(isPresented: $showSnapshotBrowser) {
            if let note = selectedNote {
                SnapshotBrowserView(note: note, isPresented: $showSnapshotBrowser)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importNote)) { _ in importNotes() }
        .onReceive(NotificationCenter.default.publisher(for: .backupLibrary)) { _ in
            saveBackup()
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreLibrary)) { _ in
            importBackup()
        }
        .focusedSceneValue(\.hasSelectedNote, selectedNote != nil)
        .tint(currentTheme == .dark ? .white : .accentColor)
        #if os(iOS)
        .toolbarBackground(currentTheme.paperColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }

    private func handleNoteDrop(urls: [URL], to folder: Folder?, trash: Bool = false) {
        for url in urls {
            guard url.scheme == "mdwriter", url.host == "note" else { continue }
            let idString = url.lastPathComponent
            if let data = Data(base64Encoded: idString),
                let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data),
                let note = modelContext.model(for: id) as? Note
            {
                executeMove(note: note, to: folder, trash: trash)
            }
        }
    }

    private func executeMove(note: Note, to folder: Folder?, trash: Bool) {
        if trash {
            moveNoteToTrash(note)
        } else {
            moveNote(note, to: folder)
        }
    }

    private var navigationTitle: String {
        switch selectionMode {
        case .all: return String(localized: "All Documents")
        case .inbox: return String(localized: "Inbox")
        case .trash: return String(localized: "Trash")
        case .folder(let folder): return folder.name
        }
    }

    private func createNewNote() {
        let newNote = Note(title: String(localized: "New Note"))
        if case .folder(let folder) = selectionMode { newNote.folder = folder }
        modelContext.insert(newNote)
        try? modelContext.save()
        selectedNote = newNote
    }

    private func moveNote(_ note: Note, to folder: Folder?) {
        note.folder = folder
        note.isTrashed = false
        try? modelContext.save()
    }

    private func moveNoteToTrash(_ note: Note) {
        note.isTrashed = true
        try? modelContext.save()
        if selectedNote == note { selectedNote = nil }
    }

    private func restoreNote(_ note: Note) {
        note.isTrashed = false
        try? modelContext.save()
    }

    private func deleteNotePermanently(_ note: Note) {
        modelContext.delete(note)
        try? modelContext.save()
        if selectedNote == note { selectedNote = nil }
    }

    private func emptyTrash() {
        // 使用 FetchDescriptor 手动获取废纸篓中的笔记，避免在视图中保留所有笔记的引用
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.isTrashed })
        if let trashedNotes = try? modelContext.fetch(descriptor) {
            trashedNotes.forEach { modelContext.delete($0) }
            try? modelContext.save()
        }
        selectedNote = nil
    }

    private func startRenamingNote(_ note: Note) {
        renamingNote = note
        newName = note.title
        isRenaming = true
    }

    private func importNotes() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text]
        panel.begin { response in
            if response == .OK {
                importNotes(from: panel.urls)
            }
        }
        #else
        showImportPicker = true
        #endif
    }
    
    private func importNotes(from urls: [URL]) {
        for url in urls {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let note = Note(
                    title: url.deletingPathExtension().lastPathComponent, content: content)
                if case .folder(let folder) = selectionMode { note.folder = folder }
                modelContext.insert(note)
            }
        }
        try? modelContext.save()
    }

    private func saveBackup() {
        guard let data = try? BackupManager.shared.createBackupData(context: modelContext) else {
            return
        }
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "mdwbk")!]
        savePanel.nameFieldStringValue =
            "MDWriter_Backup_\(Date().formatted(date: .numeric, time: .omitted))"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
            }
        }
        #else
        self.backupData = data
        self.showBackupExporter = true
        #endif
    }

    private func importBackup() {
        #if os(macOS)
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: "mdwbk")!]
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url, let data = try? Data(contentsOf: url) {
                let alert = NSAlert()
                alert.messageText = String(localized: "Restore Library")
                alert.informativeText =
                    String(
                        localized:
                            "This will replace your current library with the backup. This action cannot be undone."
                    )
                alert.addButton(withTitle: String(localized: "Restore"))
                alert.addButton(withTitle: String(localized: "Cancel"))

                if alert.runModal() == .alertFirstButtonReturn {
                    try? BackupManager.shared.restoreBackup(
                        from: data, context: modelContext, replaceLibrary: true)
                }
            }
        }
        #else
        showBackupImporter = true
        #endif
    }
}

// 辅助：用于备份导出的文件包装
struct BackupDocument: FileDocument {
    var data: Data
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "mdwbk")!] }
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}

struct FolderRow: View {
    let folder: Folder
    @Binding var selection: LibraryView.SelectionMode
    @Binding var renamingFolder: Folder?
    @Binding var isRenaming: Bool
    @Binding var newName: String
    var onMoveNote: ([URL], Folder) -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Label(folder.name, systemImage: folder.icon)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .dropDestination(for: URL.self) { items, _ in
                onMoveNote(items, folder)
                return true
            }
            .contextMenu {
                Button {
                    renamingFolder = folder
                    newName = folder.name
                    isRenaming = true
                } label: {
                    Label(LocalizedStringKey("Rename"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    modelContext.delete(folder)
                } label: {
                    Label(LocalizedStringKey("Delete"), systemImage: "trash")
                }
                Button {
                    let sub = Folder(name: String(localized: "New Group"))
                    sub.parent = folder
                    modelContext.insert(sub)
                } label: {
                    Label(LocalizedStringKey("New Group"), systemImage: "folder.badge.plus")
                }
            }
            .tag(LibraryView.SelectionMode.folder(folder))

        if !folder.subfolders.isEmpty {
            ForEach(folder.subfolders.sorted(by: { $0.name < $1.name })) { sub in
                FolderRow(
                    folder: sub, selection: $selection, renamingFolder: $renamingFolder,
                    isRenaming: $isRenaming, newName: $newName, onMoveNote: onMoveNote
                )
                .padding(.leading, 10)
            }
        }
    }
}

struct NoteRowView: View {
    let note: Note
    let searchText: String
    
    // 使用 AttributedString 进行高保真 Markdown 解析
    private var summaryAttributedString: AttributedString {
        let rawSummary = summary(from: note.content)
        do {
            // 尝试将摘要解析为 AttributedString，支持内联 Markdown 样式
            return try AttributedString(markdown: rawSummary, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            // 如果解析失败（例如 Markdown 语法不完整），回退到纯文本
            return AttributedString(rawSummary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title).font(.headline).lineLimit(1)
            // 渲染解析后的 AttributedString
            Text(summaryAttributedString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxHeight: 35, alignment: .topLeading)
            Text(note.modifiedAt, style: .date).font(.caption2).foregroundColor(.tertiaryLabel)
        }.padding(.vertical, 4)
    }
    
    private func summary(from text: String) -> String {
        let contentLines = text.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#")
        }
        return contentLines.prefix(2).joined(separator: " ")
    }
}

struct EditorWrapper: View {
    var note: Note?
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var showOutline: Bool
    @Binding var textZoom: CGFloat
    var body: some View {
        ContentView(
            note: note, searchText: $searchText, isSearching: $isSearching,
            showOutline: $showOutline, textZoom: $textZoom)
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
