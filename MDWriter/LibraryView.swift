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
        case folder(Folder)
    }

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    // View menu states (synced with MDWriterApp)
    @AppStorage("showLibrary") private var showLibrary: Bool = true
    @AppStorage("showPreview") private var showPreview: Bool = false
    @AppStorage("showOutline") private var showOutline: Bool = false
    @AppStorage("textZoom") private var textZoom: Double = 1.0

    // 重命名状态
    @State private var renamingFolder: Folder?
    @State private var renamingNote: Note?
    @State private var newName: String = ""
    @State private var isRenaming: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // 第一栏：文件夹列表 (层级结构)
            List(selection: $selectionMode) {
                Section(LocalizedStringKey("Library")) {
                    Label(LocalizedStringKey("All Documents"), systemImage: "tray.full")
                        .tag(SelectionMode.all)

                    Label(LocalizedStringKey("Inbox"), systemImage: "tray")
                        .tag(SelectionMode.inbox)
                }

                Section(LocalizedStringKey("Folders")) {
                    // 使用 OutlineGroup 展示层级 (SwiftData 无级联暂用 flat)
                    ForEach(folders.filter { $0.parent == nil }) { folder in
                        FolderRow(
                            folder: folder, selection: $selectionMode,
                            renamingFolder: $renamingFolder, isRenaming: $isRenaming,
                            newName: $newName)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(LocalizedStringKey("Library"))
            .alert(LocalizedStringKey("Rename"), isPresented: $isRenaming) {
                TextField(LocalizedStringKey("New Name"), text: $newName)
                Button(LocalizedStringKey("Rename")) {
                    if let folder = renamingFolder {
                        folder.name = newName
                    } else if let note = renamingNote {
                        note.title = newName
                    }
                    try? modelContext.save()
                    isRenaming = false
                }
                Button(LocalizedStringKey("Cancel"), role: .cancel) {
                    isRenaming = false
                }
            }
            .toolbar {
                // New Group Button
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        let folder = Folder(name: String(localized: "New Group"))
                        if case .folder(let parent) = selectionMode {
                            folder.parent = parent
                        }
                        modelContext.insert(folder)
                    }) {
                        Label(LocalizedStringKey("New Group"), systemImage: "folder.badge.plus")
                    }
                    .help(LocalizedStringKey("New Group"))
                }
            }
        } content: {
            // 第二栏：文件列表
            Group {
                let filteredNotes = getNotes()

                List(selection: $selectedNote) {
                    ForEach(filteredNotes) { note in
                        NoteRowView(note: note, searchText: searchText)
                            .tag(note)
                            .contextMenu {
                                Button {
                                    startRenamingNote(note)
                                } label: {
                                    Label(LocalizedStringKey("Rename"), systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deleteNote(note)
                                } label: {
                                    Label(LocalizedStringKey("Delete"), systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: createNewNote) {
                            Label(LocalizedStringKey("New Note"), systemImage: "square.and.pencil")
                        }
                        .help(LocalizedStringKey("New Note"))
                    }
                }
            }
        } detail: {
            // 第三栏：编辑器 + 分割线
            HStack(spacing: 0) {
                Divider()
                    .ignoresSafeArea()

                Group {
                    if let selectedNote = selectedNote {
                        EditorWrapper(
                            note: selectedNote, searchText: $searchText,
                            isSearching: $isSearching,
                            showPreview: $showPreview, showOutline: $showOutline,
                            textZoom: Binding(
                                get: { CGFloat(textZoom) },
                                set: { textZoom = Double($0) }
                            ))
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
        .onChange(of: showLibrary) { newValue in
            withAnimation {
                columnVisibility = newValue ? .all : .doubleColumn
            }
        }
        .onChange(of: columnVisibility) { newValue in
            if newValue == .all {
                showLibrary = true
            } else {
                showLibrary = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNote)) { _ in
            createNewNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newFolder)) { _ in
            let folder = Folder(name: String(localized: "New Group"))
            if case .folder(let parent) = selectionMode {
                folder.parent = parent
            }
            modelContext.insert(folder)
        }
        .onReceive(NotificationCenter.default.publisher(for: .importNote)) { _ in
            importNotes()
        }
    }

    private var navigationTitle: String {
        switch selectionMode {
        case .all: return String(localized: "All Documents")
        case .inbox: return String(localized: "Inbox")
        case .folder(let folder): return folder.name
        }
    }

    private func getNotes() -> [Note] {
        let baseNotes: [Note]
        switch selectionMode {
        case .all:
            baseNotes = allNotes
        case .inbox:
            baseNotes = allNotes.filter { $0.folder == nil }
        case .folder(let folder):
            baseNotes = folder.notes.sorted(by: { $0.modifiedAt > $1.modifiedAt })
        }

        if searchText.isEmpty {
            return baseNotes
        } else {
            return baseNotes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func createNewNote() {
        let newTitle = String(localized: "New Note")
        let newNote = Note(title: newTitle)
        if case .folder(let folder) = selectionMode {
            newNote.folder = folder
        }
        modelContext.insert(newNote)
        try? modelContext.save()
        selectedNote = newNote
    }

    private func deleteNote(_ note: Note) {
        modelContext.delete(note)
        try? modelContext.save()
        if selectedNote == note {
            selectedNote = nil
        }
    }

    private func startRenamingFolder(_ folder: Folder) {
        renamingFolder = folder
        newName = folder.name
        isRenaming = true
    }

    private func startRenamingNote(_ note: Note) {
        renamingNote = note
        newName = note.title
        isRenaming = true
    }

    private func importNotes() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .text]

        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        let title = url.deletingPathExtension().lastPathComponent
                        let newNote = Note(title: title, content: content)
                        if case .folder(let folder) = selectionMode {
                            newNote.folder = folder
                        }
                        modelContext.insert(newNote)
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
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Label(folder.name, systemImage: folder.icon)
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

        // 递归显示子文件夹
        if !folder.subfolders.isEmpty {
            ForEach(folder.subfolders.sorted(by: { $0.name < $1.name })) { sub in
                FolderRow(
                    folder: sub, selection: $selection, renamingFolder: $renamingFolder,
                    isRenaming: $isRenaming, newName: $newName
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
            Text(note.title)
                .font(.headline)
                .lineLimit(1)

            Text(summary(from: note.content))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxHeight: 35, alignment: .topLeading)

            Text(note.modifiedAt, style: .date)
                .font(.caption2)
                .foregroundColor(.tertiaryLabel)
        }
        .padding(.vertical, 4)
    }

    private func summary(from text: String) -> String {
        let lines = text.split(separator: "\n")
        let contentLines = lines.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#")
        }
        return contentLines.prefix(2).joined(separator: " ")
    }
}

struct EditorWrapper: View {
    @Bindable var note: Note
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var showPreview: Bool
    @Binding var showOutline: Bool
    @Binding var textZoom: CGFloat

    var body: some View {
        ContentView(
            note: note, searchText: $searchText, isSearching: $isSearching,
            showPreview: $showPreview, showOutline: $showOutline, textZoom: $textZoom
        )
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
