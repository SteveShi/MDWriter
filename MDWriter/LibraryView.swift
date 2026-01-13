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
    @Query(sort: \Note.modifiedAt, order: .reverse) private var allNotes: [Note]

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
                let filteredNotes = getNotes()
                List(selection: $selectedNote) {
                    ForEach(filteredNotes) {
                        note in
                        NoteRowView(note: note, searchText: searchText)
                            .tag(note)
                            .draggable(note)  // 启用拖拽
                            .contextMenu {
                                if note.isTrashed {
                                    Button {
                                        restoreNote(note)
                                    } label: {
                                        Label(
                                            LocalizedStringKey("Restore"),
                                            systemImage: "arrow.uturn.backward")
                                    }
                                    Button(role: .destructive) {
                                        deleteNotePermanently(note)
                                    } label: {
                                        Label(
                                            LocalizedStringKey("Delete Permanently"),
                                            systemImage: "trash")
                                    }
                                } else {
                                    Button {
                                        startRenamingNote(note)
                                    } label: {
                                        Label(LocalizedStringKey("Rename"), systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        moveNoteToTrash(note)
                                    } label: {
                                        Label(
                                            LocalizedStringKey("Move to Trash"),
                                            systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.inset)
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack {
                            if case .trash = selectionMode {
                                Button(action: { showEmptyTrashAlert = true }) {
                                    Image(systemName: "trash.slash")
                                }
                                .disabled(filteredNotes.isEmpty)
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
        .onReceive(NotificationCenter.default.publisher(for: .importNote)) { _ in importNotes() }
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

    private func getNotes() -> [Note] {
        let baseNotes: [Note]
        switch selectionMode {
        case .all: baseNotes = allNotes.filter { !$0.isTrashed }
        case .inbox: baseNotes = allNotes.filter { $0.folder == nil && !$0.isTrashed }
        case .trash: baseNotes = allNotes.filter { $0.isTrashed }
        case .folder(let folder):
            baseNotes = folder.notes.filter { !$0.isTrashed }.sorted(by: {
                $0.modifiedAt > $1.modifiedAt
            })
        }
        return searchText.isEmpty
            ? baseNotes
            : baseNotes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.content.localizedCaseInsensitiveContains(searchText)
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
        allNotes.filter { $0.isTrashed }.forEach { modelContext.delete($0) }
        try? modelContext.save()
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
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title).font(.headline).lineLimit(1)
            Text(summary(from: note.content)).font(.caption).foregroundColor(.secondary).lineLimit(
                2
            ).frame(maxHeight: 35, alignment: .topLeading)
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
