//
//  NoteListView.swift
//  MDWriter
//

import SwiftData
import SwiftUI

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext

    // 使用 @Query 自动从数据库获取数据
    // 我们在 init 中动态初始化这个查询
    @Query private var notes: [Note]

    @Binding var selectedNote: Note?
    let selectionMode: LibraryView.SelectionMode
    let searchText: String

    // 操作回调
    var onRestore: (Note) -> Void
    var onDeletePermanently: (Note) -> Void
    var onRename: (Note) -> Void
    var onMoveToTrash: (Note) -> Void
    var onEmptyTrash: () -> Void

    init(
        selectionMode: LibraryView.SelectionMode,
        searchText: String,
        selectedNote: Binding<Note?>,
        onRestore: @escaping (Note) -> Void,
        onDeletePermanently: @escaping (Note) -> Void,
        onRename: @escaping (Note) -> Void,
        onMoveToTrash: @escaping (Note) -> Void,
        onEmptyTrash: @escaping () -> Void
    ) {
        self.selectionMode = selectionMode
        self.searchText = searchText
        self._selectedNote = selectedNote
        self.onRestore = onRestore
        self.onDeletePermanently = onDeletePermanently
        self.onRename = onRename
        self.onMoveToTrash = onMoveToTrash
        self.onEmptyTrash = onEmptyTrash

        // 捕获搜索文本到本地变量以供 Predicate 使用
        let queryText = searchText

        // 根据选择模式和搜索文本构建谓词
        // 为了避免复杂的 Predicate 表达式导致编译错误，我们保持逻辑扁平化
        if queryText.isEmpty {
            switch selectionMode {
            case .all:
                _notes = Query(filter: #Predicate<Note> { !$0.isTrashed }, sort: \.order)
            case .inbox:
                _notes = Query(
                    filter: #Predicate<Note> { $0.folder == nil && !$0.isTrashed }, sort: \.order)
            case .trash:
                _notes = Query(
                    filter: #Predicate<Note> { $0.isTrashed }, sort: \.modifiedAt, order: .reverse)
            case .folder(let folder):
                let folderID = folder.persistentModelID
                _notes = Query(
                    filter: #Predicate<Note> {
                        $0.folder?.persistentModelID == folderID && !$0.isTrashed
                    }, sort: \.order)
            }
        } else {
            // 当有搜索文本时，应用搜索过滤
            switch selectionMode {
            case .all:
                _notes = Query(
                    filter: #Predicate<Note> { note in
                        !note.isTrashed
                            && (note.title.localizedStandardContains(queryText)
                                || note.content.localizedStandardContains(queryText))
                    }, sort: \.order)
            case .inbox:
                _notes = Query(
                    filter: #Predicate<Note> { note in
                        note.folder == nil && !note.isTrashed
                            && (note.title.localizedStandardContains(queryText)
                                || note.content.localizedStandardContains(queryText))
                    }, sort: \.order)
            case .trash:
                _notes = Query(
                    filter: #Predicate<Note> { note in
                        note.isTrashed
                            && (note.title.localizedStandardContains(queryText)
                                || note.content.localizedStandardContains(queryText))
                    }, sort: \.modifiedAt, order: .reverse)
            case .folder(let folder):
                let folderID = folder.persistentModelID
                _notes = Query(
                    filter: #Predicate<Note> { note in
                        note.folder?.persistentModelID == folderID && !note.isTrashed
                            && (note.title.localizedStandardContains(queryText)
                                || note.content.localizedStandardContains(queryText))
                    }, sort: \.order)
            }
        }
    }

    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                NoteRowView(note: note, searchText: searchText)
                    .tag(note)
                    .draggable(NoteTransfer(id: note.persistentModelID))
                    .contextMenu {
                        if note.isTrashed {
                            Button {
                                onRestore(note)
                            } label: {
                                Label(
                                    LocalizedStringKey("Restore"),
                                    systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                onDeletePermanently(note)
                            } label: {
                                Label(
                                    LocalizedStringKey("Delete Permanently"), systemImage: "trash")
                            }
                        } else {
                            Button {
                                onRename(note)
                            } label: {
                                Label(LocalizedStringKey("Rename"), systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                onMoveToTrash(note)
                            } label: {
                                Label(LocalizedStringKey("Move to Trash"), systemImage: "trash")
                            }
                        }
                    }
            }
            .onMove(perform: moveNotes)
        }
        .listStyle(.inset)
    }

    private func moveNotes(from source: IndexSet, to destination: Int) {
        var updatedNotes = notes
        updatedNotes.move(fromOffsets: source, toOffset: destination)

        for reverseIndex in 0..<updatedNotes.count {
            updatedNotes[reverseIndex].order = reverseIndex
        }

        try? modelContext.save()
    }
}
