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

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
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

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectionMode) {
                Section(LocalizedStringKey("Library")) {
                    Label(LocalizedStringKey("All Documents"), systemImage: "tray.full")
                        .tag(SelectionMode.all)

                    Label(LocalizedStringKey("Inbox"), systemImage: "tray")

                        .tag(SelectionMode.inbox)

                        .frame(maxWidth: .infinity, alignment: .leading)

                        .contentShape(Rectangle())

                        .dropDestination(for: URL.self) { items, _ in
                            handleNoteDrop(urls: items, to: nil)
                            return true
                        }

                    Label(LocalizedStringKey("Trash"), systemImage: "trash")

                        .tag(SelectionMode.trash)

                        .frame(maxWidth: .infinity, alignment: .leading)

                        .contentShape(Rectangle())

                        .dropDestination(for: URL.self) { items, _ in
                            handleNoteDrop(urls: items, to: nil, trash: true)
                            return true
                        }

                }

                Section(LocalizedStringKey("Folders")) {

                    ForEach(folders.filter { $0.parent == nil }) { folder in

                        FolderRow(

                            folder: folder, selection: $selectionMode,

                            renamingFolder: $renamingFolder, isRenaming: $isRenaming,

                            newName: $newName,
                            onMoveNote: { urls, targetFolder in
                                handleNoteDrop(urls: urls, to: targetFolder)
                            })

                    }

                }

            }
            .listStyle(.sidebar)
            .navigationTitle(LocalizedStringKey("Library"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        let folder = Folder(name: String(localized: "New Group"))
                        if case .folder(let parent) = selectionMode { folder.parent = parent }
                        modelContext.insert(folder)
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help(LocalizedStringKey("New Group"))
                }
            }
        } content: {
            Group {
                // 使用优化后的 NoteListView 替代原来的 List
                NoteListView(
                    selectionMode: selectionMode,
                    searchText: searchText,
                    selectedNote: $selectedNote,
                    onRestore: restoreNote,
                    onDeletePermanently: deleteNotePermanently,
                    onRename: startRenamingNote,
                    onMoveToTrash: moveNoteToTrash,
                    onEmptyTrash: emptyTrash
                )
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack {
                            if case .trash = selectionMode {
                                Button(action: { showEmptyTrashAlert = true }) {
                                    Image(systemName: "trash.slash")
                                }
                            } else {
                                Button(action: createNewNote) {
                                    Image(systemName: "square.and.pencil")
                                }
                            }
                        }
                    }
                }
            }
        } detail: {
            EditorWrapper(
                note: selectedNote, searchText: $searchText, isSearching: $isSearching,
                showOutline: $showOutline,
                textZoom: Binding(get: { CGFloat(textZoom) }, set: { textZoom = Double($0) })
            )
        }
        .onChange(of: showLibrary) { newValue in
            withAnimation { columnVisibility = newValue ? .all : .doubleColumn }
        }
        .onChange(of: columnVisibility) { newValue in showLibrary = (newValue == .all) }
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
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text]
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        let note = Note(
                            title: url.deletingPathExtension().lastPathComponent, content: content)
                        if case .folder(let folder) = selectionMode { note.folder = folder }
                        modelContext.insert(note)
                    }
                }
                try? modelContext.save()
            }
        }
    }

    private func saveBackup() {
        guard let data = try? BackupManager.shared.createBackupData(context: modelContext) else {
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "mdwbk")!]
        savePanel.nameFieldStringValue =
            "MDWriter_Backup_\(Date().formatted(date: .numeric, time: .omitted))"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
            }
        }
    }

    private func importBackup() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: "mdwbk")!]
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url, let data = try? Data(contentsOf: url) {

                // Alert confirm replace or merge?
                // For simplified UX, let's ask: "Replace Library" or "Cancel" (since restore implies full restore usually)
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
