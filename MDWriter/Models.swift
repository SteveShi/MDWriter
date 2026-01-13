//
//  Models.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

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

    init(title: String, content: String = "", folder: Folder? = nil) {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isTrashed = false
        self.folder = folder
    }
}

// 扩展 Note 以支持高可靠性的混合传输
extension Note: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // 1. 优先尝试 DataRepresentation (处理 ID)
        DataRepresentation(exportedContentType: .noteIdentifier) { note in
            try JSONEncoder().encode(note.persistentModelID)
        }
        // 2. 备选 URLRepresentation (处理跨组件传输)
        ProxyRepresentation(exporting: { note in
            let data = try! JSONEncoder().encode(note.persistentModelID)
            let base64 = data.base64EncodedString()
            return URL(string: "mdwriter-note://handle?id=\(base64)")!
        })
    }
}