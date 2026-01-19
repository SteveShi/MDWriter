//
//  LibraryView.swift
//  MDWriter
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]

    @State private var selectedFolder: Folder?
    @State private var selectedNote: Note?
    @State private var selectionMode: SelectionMode? = .all

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
    
    @State private var showImportPicker: Bool = false
    @State private var showBackupExporter: Bool = false
    @State private var showBackupImporter: Bool = false
    @State private var backupData: Data?

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            sidebarView
        } content: {
            contentView
        } detail: {
            detailView
        }
        .tint(currentTheme == .dark ? .white : .accentColor)
        #if os(iOS)
        .toolbarBackground(currentTheme.paperColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.plainText, .text], allowsMultipleSelection: true) { result in
            if let urls = try? result.get() { importNotes(from: urls) }
        }
        .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [UTType(filenameExtension: "mdwbk")!]) { result in
            if let url = try? result.get(), let data = try? Data(contentsOf: url) {
                try? BackupManager.shared.restoreBackup(from: data, context: modelContext, replaceLibrary: true)
            }
        }
        .fileExporter(isPresented: $showBackupExporter, document: backupData.map { BackupDocument(data: $0) }, contentType: UTType(filenameExtension: "mdwbk")!) { _ in
            backupData = nil
        }
        .onChange(of: showLibrary) { _, newValue in
            #if os(macOS)
            if (newValue && columnVisibility.wrappedValue == .doubleColumn) || (!newValue && columnVisibility.wrappedValue == .all) {
                withAnimation { columnVisibility.wrappedValue = newValue ? .all : .doubleColumn }
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in createNewNote() }
        .onReceive(NotificationCenter.default.publisher(for: .newFolder)) { _ in
            let folder = Folder(name: String(localized: "New Group"))
            if case .folder(let parent) = selectionMode ?? .all { folder.parent = parent }
            modelContext.insert(folder)
        }
        .alert(isPresented: $showEmptyTrashAlert) {
            Alert(
                title: Text(LocalizedStringKey("Empty Trash")),
                message: Text(LocalizedStringKey("Are you sure?")),
                primaryButton: .destructive(Text(LocalizedStringKey("Empty Trash")), action: emptyTrash),
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showSnapshotBrowser) {
            if let note = selectedNote { SnapshotBrowserView(note: note, isPresented: $showSnapshotBrowser) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importNote)) { _ in importNotes() }
        .onReceive(NotificationCenter.default.publisher(for: .backupLibrary)) { _ in saveBackup() }
        .onReceive(NotificationCenter.default.publisher(for: .restoreLibrary)) { _ in importBackup() }
        #if os(macOS)
        .focusedSceneValue(\ .hasSelectedNote, selectedNote != nil)
        #endif
    }

    @ViewBuilder
    private var sidebarView: some View {
        List(selection: $selectionMode) {
            sidebarContent
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #else
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
        .background(currentTheme.paperColor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    let folder = Folder(name: String(localized: "New Group"))
                    modelContext.insert(folder)
                }) { Image(systemName: "folder.badge.plus") }
            }
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        Section(LocalizedStringKey("Library")) {
            Label(LocalizedStringKey("All Documents"), systemImage: "tray.full").tag(SelectionMode.all as SelectionMode?)
            Label(LocalizedStringKey("Inbox"), systemImage: "tray").tag(SelectionMode.inbox as SelectionMode?)
            Label(LocalizedStringKey("Trash"), systemImage: "trash").tag(SelectionMode.trash as SelectionMode?)
        }
        Section(LocalizedStringKey("Folders")) {
            ForEach(folders.filter { $0.parent == nil }) { folder in
                FolderRow(folder: folder, selection: $selectionMode, renamingFolder: $renamingFolder, isRenaming: $isRenaming, newName: $newName, onMoveNote: { urls, target in handleNoteDrop(urls: urls, to: target) })
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        NoteListView(
            selectionMode: selectionMode ?? .all, searchText: searchText, selectedNote: $selectedNote,
            onRestore: restoreNote, onDeletePermanently: deleteNotePermanently, onRename: startRenamingNote,
            onMoveToTrash: moveNoteToTrash, onEmptyTrash: { showEmptyTrashAlert = true }
        )
        .navigationTitle(navigationTitle)
        .scrollContentBackground(.hidden)
        .background(currentTheme.paperColor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewNote) { Image(systemName: "square.and.pencil") }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        EditorWrapper(
            note: selectedNote, searchText: $searchText, isSearching: $isSearching,
            showOutline: $showOutline, textZoom: Binding(get: { CGFloat(textZoom) }, set: { textZoom = Double($0) })
        )
    }

    private func handleNoteDrop(urls: [URL], to folder: Folder?, trash: Bool = false) {
        for url in urls {
            guard url.scheme == "mdwriter", url.host == "note" else { continue }
            let idString = url.lastPathComponent
            if let data = Data(base64Encoded: idString),
                let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data),
                let note = modelContext.model(for: id) as? Note
            {
                if trash { note.isTrashed = true }
                else { note.folder = folder; note.isTrashed = false }
            }
        }
        try? modelContext.save()
    }

    private var navigationTitle: String {
        switch selectionMode ?? .all {
        case .all: return String(localized: "All Documents")
        case .inbox: return String(localized: "Inbox")
        case .trash: return String(localized: "Trash")
        case .folder(let folder): return folder.name
        }
    }

    private func createNewNote() {
        let newNote = Note(title: String(localized: "New Note"))
        if case .folder(let folder) = selectionMode ?? .all { newNote.folder = folder }
        modelContext.insert(newNote)
        selectedNote = newNote
    }

    private func moveNoteToTrash(_ note: Note) {
        note.isTrashed = true
        if selectedNote == note { selectedNote = nil }
    }

    private func restoreNote(_ note: Note) { note.isTrashed = false }

    private func deleteNotePermanently(_ note: Note) {
        modelContext.delete(note)
        if selectedNote == note { selectedNote = nil }
    }

    private func emptyTrash() {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.isTrashed })
        if let trashedNotes = try? modelContext.fetch(descriptor) {
            trashedNotes.forEach { modelContext.delete($0) }
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
            if response == .OK { importNotes(from: panel.urls) }
        }
        #else
        showImportPicker = true
        #endif
    }
    
    private func importNotes(from urls: [URL]) {
        for url in urls {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let note = Note(title: url.deletingPathExtension().lastPathComponent, content: content)
                if case .folder(let folder) = selectionMode ?? .all { note.folder = folder }
                modelContext.insert(note)
            }
        }
    }

    private func saveBackup() {
        guard let data = try? BackupManager.shared.createBackupData(context: modelContext) else { return }
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "mdwbk")!]
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url { try? data.write(to: url) }
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
                try? BackupManager.shared.restoreBackup(from: data, context: modelContext, replaceLibrary: true)
            }
        }
        #else
        showBackupImporter = true
        #endif
    }
}

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
    @Binding var selection: LibraryView.SelectionMode?
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
                } label: { Label(LocalizedStringKey("Rename"), systemImage: "pencil") }
                Button(role: .destructive) { modelContext.delete(folder) } label: { Label(LocalizedStringKey("Delete"), systemImage: "trash") }
                Button {
                    let sub = Folder(name: String(localized: "New Group"))
                    sub.parent = folder
                    modelContext.insert(sub)
                } label: { Label(LocalizedStringKey("New Group"), systemImage: "folder.badge.plus") }
            }
            .tag(LibraryView.SelectionMode.folder(folder) as LibraryView.SelectionMode?)

        if !folder.subfolders.isEmpty {
            ForEach(folder.subfolders.sorted(by: { $0.name < $1.name })) { sub in
                FolderRow(folder: sub, selection: $selection, renamingFolder: $renamingFolder, isRenaming: $isRenaming, newName: $newName, onMoveNote: onMoveNote)
                .padding(.leading, 10)
            }
        }
    }
}

struct NoteRowView: View {
    let note: Note
    let searchText: String
    private var summaryAttributedString: AttributedString {
        let rawSummary = summary(from: note.content)
        return (try? AttributedString(markdown: rawSummary, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(rawSummary)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title).font(.headline).lineLimit(1)
            Text(summaryAttributedString).font(.caption).foregroundColor(.secondary).lineLimit(2).frame(maxHeight: 35, alignment: .topLeading)
            Text(note.modifiedAt, style: .date).font(.caption2).foregroundColor(.tertiaryLabel)
        }.padding(.vertical, 4)
    }
    private func summary(from text: String) -> String {
        let contentLines = text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") }
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
        ContentView(note: note, searchText: $searchText, isSearching: $isSearching, showOutline: $showOutline, textZoom: $textZoom)
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