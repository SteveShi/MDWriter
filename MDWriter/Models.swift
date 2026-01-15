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
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Snapshot.note)
    var snapshots: [Snapshot] = []

    init(title: String, content: String = "", folder: Folder? = nil) {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isTrashed = false
        self.folder = folder
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

extension Note: Transferable, @unchecked Sendable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { note in
            // 将 ID 编码为 Base64 字符串，封装在 URL 中
            let data = try! JSONEncoder().encode(note.persistentModelID)
            let base64 = data.base64EncodedString()
            return URL(string: "mdwriter://note/\(base64)")!
        })
    }
}
