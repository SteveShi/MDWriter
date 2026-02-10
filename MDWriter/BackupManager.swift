//
//  BackupManager.swift
//  MDWriter
//
//  Created for v1.7.0
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Backup Models (JSON Codable)

struct BackupRoot: Codable, Sendable {
    let version: String
    let createdAt: Date
    let folders: [BackupFolder]
    let rootNotes: [BackupNote]
}

struct BackupFolder: Codable, Sendable {
    let name: String
    let icon: String
    let subfolders: [BackupFolder]
    let notes: [BackupNote]
}

struct BackupNote: Codable, Sendable {
    let title: String
    let content: String
    let createdAt: Date
    let modifiedAt: Date
    let isTrashed: Bool
    let order: Int
    let snapshots: [BackupSnapshot]
}

struct BackupSnapshot: Codable, Sendable {
    let content: String
    let createdAt: Date
}

// MARK: - Backup Manager

@MainActor
class BackupManager {
    static let shared = BackupManager()

    // MARK: - Export

    func createBackupData(context: ModelContext) throws -> Data {
        // Fetch all root folders
        let folderDescriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.parent == nil })
        let rootFolders = try context.fetch(folderDescriptor)

        // Fetch all root notes (notes without folder)
        let noteDescriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.folder == nil })
        let rootNotesModels = try context.fetch(noteDescriptor)

        // Map to backup models
        let backupFolders = rootFolders.map { mapFolder($0) }
        let backupRootNotes = rootNotesModels.map { mapNote($0) }

        // Create root object
        let backup = BackupRoot(
            version: "1.0",
            createdAt: Date(),
            folders: backupFolders,
            rootNotes: backupRootNotes
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    private func mapFolder(_ folder: Folder) -> BackupFolder {
        BackupFolder(
            name: folder.name,
            icon: folder.icon,
            subfolders: folder.subfolders.map { mapFolder($0) },
            notes: folder.notes.map { mapNote($0) }
        )
    }

    private func mapNote(_ note: Note) -> BackupNote {
        BackupNote(
            title: note.title,
            content: note.content,
            createdAt: note.createdAt,
            modifiedAt: note.modifiedAt,
            isTrashed: note.isTrashed,
            order: note.order,
            snapshots: note.snapshots.map {
                BackupSnapshot(content: $0.content, createdAt: $0.createdAt)
            }
        )
    }

    // MARK: - Import

    func restoreBackup(from data: Data, context: ModelContext, replaceLibrary: Bool) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupRoot.self, from: data)

        if replaceLibrary {
            // 先删除 Folder（级联删除其下的 Note 和 Snapshot）
            try context.delete(model: Folder.self)
            // 再删除剩余的无文件夹 Note（级联删除其 Snapshot 和 Memo）
            try context.delete(model: Note.self)
            try context.delete(model: Snapshot.self)
            try context.delete(model: Memo.self)
        }

        // Restore Folders（递归插入子文件夹和笔记）
        for backupFolder in backup.folders {
            let folder = restoreFolder(backupFolder, context: context)
            context.insert(folder)
        }

        // Restore Root Notes（无文件夹的笔记）
        for backupNote in backup.rootNotes {
            let note = restoreNote(backupNote, context: context)
            context.insert(note)
        }

        try context.save()
    }

    private func restoreFolder(_ backup: BackupFolder, context: ModelContext) -> Folder {
        let folder = Folder(name: backup.name, icon: backup.icon)

        for sub in backup.subfolders {
            let subFolder = restoreFolder(sub, context: context)
            subFolder.parent = folder
            context.insert(subFolder)
        }

        for noteBackup in backup.notes {
            let note = restoreNote(noteBackup, context: context)
            note.folder = folder
            context.insert(note)
        }

        return folder
    }

    private func restoreNote(_ backup: BackupNote, context: ModelContext) -> Note {
        let note = Note(title: backup.title, content: backup.content, order: backup.order)
        note.createdAt = backup.createdAt
        note.modifiedAt = backup.modifiedAt
        note.isTrashed = backup.isTrashed

        // 先插入 note，确保 snapshot 的关系能正确建立
        context.insert(note)

        for snapBackup in backup.snapshots {
            let snapshot = Snapshot(content: snapBackup.content, note: note)
            snapshot.createdAt = snapBackup.createdAt
            context.insert(snapshot)
        }

        return note
    }
}
