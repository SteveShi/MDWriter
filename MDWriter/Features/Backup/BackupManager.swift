//
//  BackupManager.swift
//  MDWriter
//
//  Created for v1.7.0 & v3.0 Encrypted Backup
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

    func createBackupData(context: ModelContext, password: String? = nil) throws -> Data {
        let folderDescriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.parent == nil })
        let rootFolders = try context.fetch(folderDescriptor)

        let noteDescriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.folder == nil })
        let rootNotesModels = try context.fetch(noteDescriptor)

        let backupFolders = rootFolders.map { mapFolder($0) }
        let backupRootNotes = rootNotesModels.map { mapNote($0) }

        let backup = BackupRoot(
            version: "3.0",
            createdAt: Date(),
            folders: backupFolders,
            rootNotes: backupRootNotes
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let rawJSON = try encoder.encode(backup)

        if let pwd = password, !pwd.isEmpty {
            return try CryptoManager.shared.encrypt(data: rawJSON, password: pwd)
        } else {
            return rawJSON
        }
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

    func restoreBackup(from data: Data, password: String? = nil, context: ModelContext, replaceLibrary: Bool) throws {
        var payload = data

        if CryptoManager.shared.isEncrypted(data: data) {
            guard let pwd = password, !pwd.isEmpty else {
                throw CryptoError.missingPassword
            }
            payload = try CryptoManager.shared.decrypt(data: data, password: pwd)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupRoot.self, from: payload)

        if replaceLibrary {
            try context.delete(model: Folder.self)
            try context.delete(model: Note.self)
            try context.delete(model: Snapshot.self)
            try context.delete(model: Memo.self)
        }

        for backupFolder in backup.folders {
            let folder = restoreFolder(backupFolder, context: context)
            context.insert(folder)
        }

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

        context.insert(note)

        for snapBackup in backup.snapshots {
            let snapshot = Snapshot(content: snapBackup.content, note: note)
            snapshot.createdAt = snapBackup.createdAt
            context.insert(snapshot)
        }

        return note
    }
}
