//
//  WikiLinkCompletionPopover.swift
//  MDWriter
//
//  编辑器内 `[[` 双向链接自动补全浮层（对标 UlyssesUI.LinkCompletionCell）：
//  由 MDEditorKit 的轻量 EditorWikiLinkQuery 驱动，零全文扫描，支持键盘选择与快速建链。
//

import MDEditorKit
import SwiftData
import SwiftUI

struct WikiLinkCompletionPopover: View {
    let query: EditorWikiLinkQuery
    let currentNoteID: PersistentIdentifier?
    @ObservedObject var controller: EditorController

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { !$0.isTrashed }, sort: \Note.modifiedAt, order: .reverse)
    private var allNotes: [Note]

    @State private var selectedIndex: Int = 0
    @State private var dismissedRange: NSRange? = nil

    private var matchingNotes: [Note] {
        let q = query.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = allNotes.filter { note in
            note.persistentModelID != currentNoteID
                && !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !q.isEmpty else {
            return Array(candidates.prefix(8))
        }
        let filtered = candidates.filter { $0.title.lowercased().contains(q) }
        return Array(
            filtered.sorted { lhs, rhs in
                let lPrefix = lhs.title.lowercased().hasPrefix(q)
                let rPrefix = rhs.title.lowercased().hasPrefix(q)
                if lPrefix != rPrefix { return lPrefix }
                return lhs.modifiedAt > rhs.modifiedAt
            }.prefix(8)
        )
    }

    private var canCreateNewNote: Bool {
        let trimmed = query.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !allNotes.contains { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        if dismissedRange != query.replaceRange {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(LocalizedStringKey("Link to Note"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !query.query.isEmpty {
                        Text(query.query)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.03))

                Divider().opacity(0.35)

                if matchingNotes.isEmpty && !canCreateNewNote {
                    Text(LocalizedStringKey("No matching notes"))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(matchingNotes.enumerated()), id: \.element.persistentModelID) { idx, note in
                            Button {
                                controller.insertWikiLink(title: note.title, replacing: query)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 11))
                                        .foregroundColor(idx == selectedIndex ? .accentColor : .secondary)

                                    Text(note.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    Spacer()

                                    if let folderName = note.folder?.name, !folderName.isEmpty {
                                        Text(folderName)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(idx == selectedIndex ? Color.accentColor.opacity(0.14) : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering { selectedIndex = idx }
                            }
                        }

                        if canCreateNewNote {
                            let newTitle = query.query.trimmingCharacters(in: .whitespacesAndNewlines)
                            Divider().opacity(0.35).padding(.vertical, 2)
                            Button {
                                createAndInsertLink(title: newTitle)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor)
                                    Text(String(localized: "Create \"\(newTitle)\""))
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                }
            }
            .frame(width: 280)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
            .onChange(of: query.query) { _, _ in
                selectedIndex = 0
                dismissedRange = nil
            }
            .onKeyPress(.escape) {
                dismissedRange = query.replaceRange
                return .handled
            }
        }
    }

    private func createAndInsertLink(title: String) {
        let newNote = Note(title: title, content: "# \(title)\n\n")
        modelContext.insert(newNote)
        try? modelContext.save()
        controller.insertWikiLink(title: title, replacing: query)
    }
}
