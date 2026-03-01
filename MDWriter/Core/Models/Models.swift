//
//  Models.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var markdownDocument: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
    static var noteIdentifier: UTType {
        UTType(exportedAs: "com.mdwriter.note")
    }
}

// Simplified Theme Model for Markdown
enum MarkdownTheme: String, CaseIterable, Identifiable {
    case pure = "Pure"
    case solarizedLight = "Solarized Light"
    case solarizedDark = "Solarized Dark"
    case github = "GitHub"
    case dracula = "Dracula"
    case nord = "Nord"
    case monokai = "Monokai"
    case nightOwl = "Night Owl"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .pure: return LocalizedStringKey("Pure")
        case .solarizedLight: return LocalizedStringKey("Solarized Light")
        case .solarizedDark: return LocalizedStringKey("Solarized Dark")
        case .github: return LocalizedStringKey("GitHub")
        case .dracula: return LocalizedStringKey("Dracula")
        case .nord: return LocalizedStringKey("Nord")
        case .monokai: return LocalizedStringKey("Monokai")
        case .nightOwl: return LocalizedStringKey("Night Owl")
        }
    }
}

@Model
final class Folder {
    var name: String
    var createdAt: Date
    var icon: String

    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note] = []

    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var subfolders: [Folder] = []

    var parent: Folder?

    init(name: String, icon: String = "folder") {
        self.name = name
        self.icon = icon
        self.createdAt = Date()
    }
}

@Model
final class Note {
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isTrashed: Bool = false
    var order: Int = 0  // 用于记录手动排序顺序
    var tags: [String] = []  // Keywords
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Snapshot.note)
    var snapshots: [Snapshot] = []

    @Relationship(deleteRule: .cascade, inverse: \Memo.note)
    var memos: [Memo] = []  // Multiple separate notes

    init(title: String, content: String = "", folder: Folder? = nil, order: Int = 0) {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isTrashed = false
        self.folder = folder
        self.order = order
    }
}

@Model
final class Memo {
    var content: String
    var createdAt: Date
    var note: Note?

    init(content: String, note: Note? = nil) {
        self.content = content
        self.createdAt = Date()
        self.note = note
    }
}

@Model
final class Snapshot {
    var content: String
    var createdAt: Date
    var note: Note?

    init(content: String, note: Note? = nil) {
        self.content = content
        self.createdAt = Date()
        self.note = note
    }
}

struct NoteTransfer: Codable, Transferable, Sendable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { noteTransfer in
            let data = try! JSONEncoder().encode(noteTransfer.id)
            let base64 = data.base64EncodedString()
            return URL(string: "mdwriter://note/\(base64)")!
        })
    }
}
