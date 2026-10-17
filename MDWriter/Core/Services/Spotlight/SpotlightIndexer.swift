//
//  SpotlightIndexer.swift
//  MDWriter
//
//  Created by Steve Shi on 2026/10/18.
//

import CoreSpotlight
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// macOS 系统级 Spotlight 搜索索引管理器
@MainActor
final class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    static let domainIdentifier = "com.steveshi.mdwriter.notes"

    private init() {}

    /// 为单篇笔记建立或更新 Spotlight 索引
    func indexNote(_ note: Note) {
        guard !note.isTrashed else {
            removeNote(note)
            return
        }

        guard let data = try? JSONEncoder().encode(note.persistentModelID) else { return }
        let identifier = "mdwriter://note/\(data.base64EncodedString())"

        let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)
        attributeSet.title = note.title.isEmpty ? String(localized: "Untitled Note") : note.title
        attributeSet.contentDescription = String(note.content.prefix(300))
        attributeSet.textContent = note.content
        attributeSet.keywords = note.tags
        attributeSet.containerTitle = note.folder?.name ?? String(localized: "Inbox")
        attributeSet.contentModificationDate = note.modifiedAt

        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("[SpotlightIndexer] Failed to index note: \(error.localizedDescription)")
            }
        }
    }

    /// 从 Spotlight 中删除某篇笔记
    func removeNote(_ note: Note) {
        guard let data = try? JSONEncoder().encode(note.persistentModelID) else { return }
        let identifier = "mdwriter://note/\(data.base64EncodedString())"

        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
            if let error = error {
                print("[SpotlightIndexer] Failed to remove note from spotlight: \(error.localizedDescription)")
            }
        }
    }

    /// 全量重新索引所有未删除的笔记
    func reindexAllNotes(_ notes: [Note]) {
        let validNotes = notes.filter { !$0.isTrashed }
        var items: [CSSearchableItem] = []

        for note in validNotes {
            guard let data = try? JSONEncoder().encode(note.persistentModelID) else { continue }
            let identifier = "mdwriter://note/\(data.base64EncodedString())"

            let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)
            attributeSet.title = note.title.isEmpty ? String(localized: "Untitled Note") : note.title
            attributeSet.contentDescription = String(note.content.prefix(300))
            attributeSet.textContent = note.content
            attributeSet.keywords = note.tags
            attributeSet.containerTitle = note.folder?.name ?? String(localized: "Inbox")
            attributeSet.contentModificationDate = note.modifiedAt

            let item = CSSearchableItem(
                uniqueIdentifier: identifier,
                domainIdentifier: Self.domainIdentifier,
                attributeSet: attributeSet
            )
            items.append(item)
        }

        guard !items.isEmpty else { return }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("[SpotlightIndexer] Failed to batch index notes: \(error.localizedDescription)")
            }
        }
    }
}
