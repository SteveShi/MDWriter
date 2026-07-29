//
//  DropboxSyncService.swift
//  MDWriter
//
//  Dropbox Cloud & Folder Synchronization Service with E2EE Encryption
//

import Combine
import Foundation
import SwiftData
import SwiftUI

public enum DropboxSyncMode: String, CaseIterable, Identifiable {
    case localFolder = "Local Dropbox Directory"
    case apiToken = "Dropbox REST API"

    public var id: String { rawValue }
}

public enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case success(Date)
    case error(String)

    public var localizedDescription: String {
        switch self {
        case .idle:
            return String(localized: "Ready to sync", comment: "Sync status")
        case .syncing:
            return String(localized: "Synchronizing...", comment: "Sync status")
        case .success(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .short
            return String(localized: "Last synced: \(formatter.string(from: date))", comment: "Sync status")
        case .error(let msg):
            return String(localized: "Sync error: \(msg)", comment: "Sync status")
        }
    }
}

@MainActor
public class DropboxSyncService: ObservableObject {
    public static let shared = DropboxSyncService()

    @AppStorage("dropboxSyncEnabled") public var isSyncEnabled: Bool = false {
        didSet { configureTimer() }
    }
    @AppStorage("dropboxSyncMode") public var syncModeRaw: String = DropboxSyncMode.localFolder.rawValue
    @AppStorage("dropboxFolderPath") public var customFolderPath: String = ""
    @AppStorage("dropboxAPIToken") public var apiToken: String = ""
    @AppStorage("dropboxAutoSyncInterval") public var autoSyncIntervalMinutes: Int = 15 {
        didSet { configureTimer() }
    }
    @AppStorage("dropboxEncryptSync") public var encryptSyncData: Bool = true
    @AppStorage("dropboxLastSyncTimestamp") public var lastSyncTimestamp: Double = 0

    @Published public var syncStatus: SyncStatus = .idle

    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    public var syncMode: DropboxSyncMode {
        DropboxSyncMode(rawValue: syncModeRaw) ?? .localFolder
    }

    public var defaultDropboxFolderURL: URL {
        if !customFolderPath.isEmpty {
            return URL(fileURLWithPath: customFolderPath)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dropboxAppFolder = home.appendingPathComponent("Dropbox/Apps/MDWriter")
        return dropboxAppFolder
    }

    private init() {
        configureTimer()
    }

    // MARK: - Timer Configuration

    public func configureTimer() {
        syncTimer?.invalidate()
        syncTimer = nil

        guard isSyncEnabled && autoSyncIntervalMinutes > 0 else { return }

        let interval = TimeInterval(autoSyncIntervalMinutes * 60)
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performSync(context: nil)
            }
        }
    }

    // MARK: - Core Sync Execution

    public func performSync(context: ModelContext?) {
        guard isSyncEnabled else { return }
        guard syncStatus != .syncing else { return }

        syncStatus = .syncing

        Task {
            do {
                let password = CryptoManager.shared.getMasterPassword()

                if syncMode == .localFolder {
                    try await syncWithLocalFolder(context: context, password: password)
                } else {
                    try await syncWithDropboxAPI(context: context, password: password)
                }

                let now = Date()
                lastSyncTimestamp = now.timeIntervalSince1970
                syncStatus = .success(now)
            } catch {
                syncStatus = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Local Folder Sync (Dropbox App Sync Integration)

    private func syncWithLocalFolder(context: ModelContext?, password: String?) async throws {
        let folderURL = defaultDropboxFolderURL
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: folderURL.path) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }

        let syncFileName = encryptSyncData ? "mdwriter_vault.mdwbk.enc" : "mdwriter_vault.mdwbk"
        let syncFileURL = folderURL.appendingPathComponent(syncFileName)

        // 1. If remote file exists and is newer, restore remote changes
        if fileManager.fileExists(atPath: syncFileURL.path) {
            let attrs = try fileManager.attributesOfItem(atPath: syncFileURL.path)
            if let modDate = attrs[.modificationDate] as? Date,
               modDate.timeIntervalSince1970 > lastSyncTimestamp,
               let modelContext = context {
                let remoteData = try Data(contentsOf: syncFileURL)
                try BackupManager.shared.restoreBackup(from: remoteData, password: password, context: modelContext, replaceLibrary: false)
            }
        }

        // 2. Export local library snapshot to sync file
        if let modelContext = context {
            let localData = try BackupManager.shared.createBackupData(context: modelContext, password: encryptSyncData ? password : nil)
            try localData.write(to: syncFileURL, options: .atomic)
        }
    }

    // MARK: - Dropbox REST API Sync

    private func syncWithDropboxAPI(context: ModelContext?, password: String?) async throws {
        guard !apiToken.isEmpty else {
            throw NSError(domain: "DropboxSync", code: 401, userInfo: [NSLocalizedDescriptionKey: String(localized: "Dropbox API Token is missing.", comment: "Sync error")])
        }

        let syncFileName = encryptSyncData ? "mdwriter_vault.mdwbk.enc" : "mdwriter_vault.mdwbk"
        let remotePath = "/\(syncFileName)"

        // 1. Export local snapshot
        guard let modelContext = context else { return }
        let localData = try BackupManager.shared.createBackupData(context: modelContext, password: encryptSyncData ? password : nil)

        // 2. Upload to Dropbox API v2 /2/files/upload
        let uploadURL = URL(string: "https://content.dropboxapi.com/2/files/upload")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let apiArg: [String: Any] = [
            "path": remotePath,
            "mode": "overwrite",
            "autorename": false,
            "mute": false
        ]

        let argData = try JSONSerialization.data(withJSONObject: apiArg)
        request.setValue(String(data: argData, encoding: .utf8), forHTTPHeaderField: "Dropbox-API-Arg")
        request.httpBody = localData

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let respStr = String(data: respData, encoding: .utf8) ?? "HTTP Error"
            throw NSError(domain: "DropboxSync", code: 500, userInfo: [NSLocalizedDescriptionKey: "Dropbox API Upload Failed: \(respStr)"])
        }
    }
}
