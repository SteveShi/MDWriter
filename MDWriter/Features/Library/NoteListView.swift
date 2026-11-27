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
    @FocusState private var isListFocused: Bool
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
        let isEmpty = queryText.isEmpty

        // 根据选择模式构建谓词；搜索过滤合并进同一个 Predicate，由 isEmpty 短路
        // 保持每个 case 各自的 #Predicate，以避开 Predicate 宏对复杂表达式的限制
        switch selectionMode {
        case .all:
            _notes = Query(
                filter: #Predicate<Note> { note in
                    !note.isTrashed
                        && (isEmpty
                            || note.title.localizedStandardContains(queryText)
                            || note.content.localizedStandardContains(queryText))
                }, sort: \.order)
        case .inbox:
            _notes = Query(
                filter: #Predicate<Note> { note in
                    note.folder == nil && !note.isTrashed
                        && (isEmpty
                            || note.title.localizedStandardContains(queryText)
                            || note.content.localizedStandardContains(queryText))
                }, sort: \.order)
        case .trash:
            _notes = Query(
                filter: #Predicate<Note> { note in
                    note.isTrashed
                        && (isEmpty
                            || note.title.localizedStandardContains(queryText)
                            || note.content.localizedStandardContains(queryText))
                }, sort: \.modifiedAt, order: .reverse)
        case .folder(let folder):
            let folderID = folder.persistentModelID
            _notes = Query(
                filter: #Predicate<Note> { note in
                    note.folder?.persistentModelID == folderID && !note.isTrashed
                        && (isEmpty
                            || note.title.localizedStandardContains(queryText)
                            || note.content.localizedStandardContains(queryText))
                }, sort: \.order)
        case .tag(let tag):
            _notes = Query(
                filter: #Predicate<Note> { note in
                    note.tags.contains(tag) && !note.isTrashed
                        && (isEmpty
                            || note.title.localizedStandardContains(queryText)
                            || note.content.localizedStandardContains(queryText))
                }, sort: \.order)
        case .externalFolder:
            _notes = Query(
                filter: #Predicate<Note> { note in
                    note.externalFilePath != nil && !note.isTrashed
                        && (isEmpty
                            || note.title.localizedStandardContains(queryText)
                            || note.content.localizedStandardContains(queryText))
                }, sort: \.modifiedAt, order: .reverse)
        }
    }

    private var displayedNotes: [Note] {
        let filtered: [Note]
        if case .externalFolder(let folder) = selectionMode {
            let folderPath = folder.resolveURL()?.path ?? ""
            filtered = notes.filter { note in
                guard let path = note.externalFilePath else { return false }
                return folderPath.isEmpty || path.hasPrefix(folderPath)
            }
        } else {
            filtered = notes
        }

        return filtered.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            if case .trash = selectionMode {
                return a.modifiedAt > b.modifiedAt
            }
            return a.order < b.order
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private var sheetListBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.141, green: 0.141, blue: 0.149) // #242426 沉稳暗灰，与 #1E1E1E 编辑器拉开微阶层次
            : Color(red: 0.969, green: 0.969, blue: 0.973) // #F7F7F8 柔和浅灰，与纯白/纸色编辑器自然区分
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(displayedNotes.enumerated()), id: \.element.id) { index, note in
                    let isSelected = (selectedNote == note)
                    let nextIsSelected = (index + 1 < displayedNotes.count && selectedNote == displayedNotes[index + 1])

                    NoteRowView(
                        note: note,
                        searchText: searchText,
                        isSelected: isSelected,
                        isListFocused: isListFocused,
                        showBottomDivider: !isSelected && !nextIsSelected && index < displayedNotes.count - 1
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNote = note
                        isListFocused = true
                    }
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
                                note.isPinned.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(
                                    note.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin to Top"),
                                    systemImage: note.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            Divider()
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
            }
            .padding(.vertical, 6)
        }
        .background(sheetListBackground)
        .focusable()
        .focused($isListFocused)
        .focusEffectDisabled()
        .onKeyPress(.downArrow) {
            selectAdjacentNote(offset: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectAdjacentNote(offset: -1)
            return .handled
        }
    }

    private func selectAdjacentNote(offset: Int) {
        let items = displayedNotes
        guard !items.isEmpty else { return }
        guard let current = selectedNote, let idx = items.firstIndex(of: current) else {
            selectedNote = items.first
            return
        }
        let nextIdx = max(0, min(items.count - 1, idx + offset))
        selectedNote = items[nextIdx]
    }

    private func moveNotes(from source: IndexSet, to destination: Int) {
        var updatedNotes = displayedNotes
        updatedNotes.move(fromOffsets: source, toOffset: destination)

        for reverseIndex in 0..<updatedNotes.count {
            updatedNotes[reverseIndex].order = reverseIndex
        }

        try? modelContext.save()
    }
}
