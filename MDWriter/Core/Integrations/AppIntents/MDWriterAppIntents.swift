//
//  MDWriterAppIntents.swift
//  MDWriter
//
//  Created by Steve Shi on 2026/10/18.
//

import AppIntents
import Foundation
import SwiftData

// MARK: - 新建笔记快捷指令

struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note in MDWriter"
    static let description = IntentDescription("Create a new Markdown note in MDWriter.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Content")
    var content: String

    init() {
        self.title = ""
        self.content = ""
    }

    init(title: String, content: String) {
        self.title = title
        self.content = content
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dataFolderURL = appSupportURL.appendingPathComponent("MDWriter", isDirectory: true)
        let sqliteURL = dataFolderURL.appendingPathComponent("library.sqlite")

        let schema = Schema([Folder.self, Note.self, Snapshot.self, Memo.self, ChatMessage.self])
        let config = ModelConfiguration(url: sqliteURL, allowsSave: true)

        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return .result(value: "Failed to access MDWriter database")
        }

        let context = container.mainContext
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = cleanTitle.isEmpty ? String(localized: "Quick Note") : cleanTitle

        let newNote = Note(title: resolvedTitle, content: content)
        context.insert(newNote)
        try? context.save()

        // 同步 Spotlight 索引
        SpotlightIndexer.shared.indexNote(newNote)

        return .result(value: "Note created: \(resolvedTitle)")
    }
}

// MARK: - 搜索笔记快捷指令

struct SearchNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Notes in MDWriter"
    static let description = IntentDescription("Search notes by title or content keywords in MDWriter.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Search Query")
    var query: String

    init() {
        self.query = ""
    }

    init(query: String) {
        self.query = query
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dataFolderURL = appSupportURL.appendingPathComponent("MDWriter", isDirectory: true)
        let sqliteURL = dataFolderURL.appendingPathComponent("library.sqlite")

        let schema = Schema([Folder.self, Note.self, Snapshot.self, Memo.self, ChatMessage.self])
        let config = ModelConfiguration(url: sqliteURL, allowsSave: true)

        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return .result(value: [])
        }

        let context = container.mainContext
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return .result(value: []) }

        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { note in
                !note.isTrashed && (
                    note.title.localizedStandardContains(cleanQuery) ||
                    note.content.localizedStandardContains(cleanQuery)
                )
            }
        )

        let matched = (try? context.fetch(descriptor)) ?? []
        let titles = matched.prefix(10).map { $0.title }

        return .result(value: Array(titles))
    }
}

// MARK: - 向已有笔记追加内容快捷指令

struct AppendToNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Append Text to Note"
    static let description = IntentDescription("Append markdown text to an existing note in MDWriter.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Target Note Title")
    var noteTitle: String

    @Parameter(title: "Text to Append")
    var textToAppend: String

    init() {
        self.noteTitle = ""
        self.textToAppend = ""
    }

    init(noteTitle: String, textToAppend: String) {
        self.noteTitle = noteTitle
        self.textToAppend = textToAppend
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dataFolderURL = appSupportURL.appendingPathComponent("MDWriter", isDirectory: true)
        let sqliteURL = dataFolderURL.appendingPathComponent("library.sqlite")

        let schema = Schema([Folder.self, Note.self, Snapshot.self, Memo.self, ChatMessage.self])
        let config = ModelConfiguration(url: sqliteURL, allowsSave: true)

        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return .result(value: "Database inaccessible")
        }

        let context = container.mainContext
        let target = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return .result(value: "Title cannot be empty") }

        let descriptor = FetchDescriptor<Note>()
        let allNotes = (try? context.fetch(descriptor)) ?? []

        guard let note = allNotes.first(where: { !$0.isTrashed && $0.title.caseInsensitiveCompare(target) == .orderedSame }) else {
            return .result(value: "Note not found: \(target)")
        }

        if note.content.isEmpty {
            note.content = textToAppend
        } else {
            note.content += "\n\n" + textToAppend
        }
        note.modifiedAt = Date()
        try? context.save()

        SpotlightIndexer.shared.indexNote(note)

        return .result(value: "Successfully appended to \(note.title)")
    }
}

// MARK: - 系统快捷指令聚合提供者

struct MDWriterShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "New sheet in \(.applicationName)",
                "在 \(.applicationName) 中新建笔记"
            ],
            shortTitle: "New Note",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: [
                "Search in \(.applicationName)",
                "Find note in \(.applicationName)",
                "在 \(.applicationName) 中搜索笔记"
            ],
            shortTitle: "Search Notes",
            systemImageName: "magnifyingglass"
        )
    }
}
