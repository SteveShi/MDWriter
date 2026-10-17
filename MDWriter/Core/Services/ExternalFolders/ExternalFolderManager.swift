//
//  ExternalFolderManager.swift
//  MDWriter
//
//  Created by Steve Shi on 2026/10/18.
//

import AppKit
import Foundation
import SwiftData
import SwiftUI

/// 描述挂载的外部本地文件夹
struct ExternalFolder: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let bookmarkData: Data

    init(id: UUID = UUID(), name: String, bookmarkData: Data) {
        self.id = id
        self.name = name
        self.bookmarkData = bookmarkData
    }

    /// 解析获得具备沙盒安全访问权限的 URL
    func resolveURL() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        return url
    }
}

/// 外部本地文件夹管理器（Security-Scoped Bookmarks & 双向读写同步）
@MainActor
final class ExternalFolderManager: ObservableObject {
    static let shared = ExternalFolderManager()

    private let storageKey = "mdwriter_mounted_external_folders"

    @Published private(set) var mountedFolders: [ExternalFolder] = []
    private var activeSecurityScopedURLs: [UUID: URL] = [:]

    private init() {
        loadPersistedFolders()
    }

    deinit {
        for (_, url) in activeSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - 持久化与生命周期

    private func loadPersistedFolders() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ExternalFolder].self, from: data) else {
            return
        }

        mountedFolders = decoded
        // 依次激活沙盒权限
        for folder in mountedFolders {
            if let url = folder.resolveURL(), url.startAccessingSecurityScopedResource() {
                activeSecurityScopedURLs[folder.id] = url
            }
        }
    }

    private func savePersistedFolders() {
        if let encoded = try? JSONEncoder().encode(mountedFolders) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - 挂载与卸载

    /// 弹出系统 NSOpenPanel 让用户选择本地外部目录
    func pickAndMountFolder() -> ExternalFolder? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = String(localized: "Mount Folder")
        openPanel.message = String(localized: "Choose a folder containing Markdown files to mount.")

        guard openPanel.runModal() == .OK, let selectedURL = openPanel.url else {
            return nil
        }

        return mountFolder(at: selectedURL)
    }

    /// 挂载指定本地 URL，生成持久化安全书签
    @discardableResult
    func mountFolder(at url: URL) -> ExternalFolder? {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }

        guard let bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: [.isDirectoryKey],
            relativeTo: nil
        ) else {
            url.stopAccessingSecurityScopedResource()
            return nil
        }

        let folder = ExternalFolder(name: url.lastPathComponent, bookmarkData: bookmarkData)

        // 避免重复挂载相同路径
        if let existingIndex = mountedFolders.firstIndex(where: { $0.resolveURL()?.path == url.path }) {
            mountedFolders[existingIndex] = folder
        } else {
            mountedFolders.append(folder)
        }

        activeSecurityScopedURLs[folder.id] = url
        savePersistedFolders()
        return folder
    }

    /// 卸载外部文件夹
    func unmountFolder(_ folder: ExternalFolder) {
        if let activeURL = activeSecurityScopedURLs[folder.id] {
            activeURL.stopAccessingSecurityScopedResource()
            activeSecurityScopedURLs.removeValue(forKey: folder.id)
        }
        mountedFolders.removeAll(where: { $0.id == folder.id })
        savePersistedFolders()
    }

    // MARK: - 文件发现与磁盘读写

    /// 扫描挂载目录下所有 Markdown 文件（.md, .markdown, .txt）
    func scanMarkdownFiles(in folder: ExternalFolder) -> [URL] {
        guard let folderURL = activeSecurityScopedURLs[folder.id] ?? folder.resolveURL() else {
            return []
        }

        let fileManager = FileManager.default
        let supportedExtensions = ["md", "markdown", "txt"]

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                results.append(fileURL)
            }
        }

        return results.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    /// 实时将外部文件同步为 SwiftData 中的 Note 对象，方便复用编辑器体系
    func syncExternalNotes(for folder: ExternalFolder, in modelContext: ModelContext) -> [Note] {
        let fileURLs = scanMarkdownFiles(in: folder)
        var synchronizedNotes: [Note] = []

        // 读取当前上下文中已知的所有外部笔记
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { $0.externalFilePath != nil && !$0.isTrashed }
        )
        let existingNotes = (try? modelContext.fetch(descriptor)) ?? []
        var pathMap = Dictionary(uniqueKeysWithValues: existingNotes.compactMap { note -> (String, Note)? in
            guard let path = note.externalFilePath else { return nil }
            return (path, note)
        })

        for fileURL in fileURLs {
            let path = fileURL.path
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()

            if let existingNote = pathMap[path] {
                // 如果磁盘文件比内存笔记新，增量同步内容
                if modDate > existingNote.modifiedAt, let diskContent = try? String(contentsOf: fileURL, encoding: .utf8) {
                    existingNote.content = diskContent
                    existingNote.modifiedAt = modDate
                }
                synchronizedNotes.append(existingNote)
                pathMap.removeValue(forKey: path)
            } else {
                // 新建外部笔记镜像
                let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                let newNote = Note(title: fileName, content: content)
                newNote.externalFilePath = path
                newNote.modifiedAt = modDate
                modelContext.insert(newNote)
                synchronizedNotes.append(newNote)
            }
        }

        return synchronizedNotes
    }

    /// 在挂载文件夹中创建新的 Markdown 磁盘文件
    func createExternalMarkdownFile(in folder: ExternalFolder, title: String, content: String = "") throws -> URL {
        guard let folderURL = activeSecurityScopedURLs[folder.id] ?? folder.resolveURL() else {
            throw NSError(domain: "ExternalFolderError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Folder URL inaccessible"])
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = cleanTitle.isEmpty ? "Untitled" : cleanTitle
        var targetURL = folderURL.appendingPathComponent("\(safeName).md")

        // 避免同名覆盖，自增序列
        var counter = 1
        while FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = folderURL.appendingPathComponent("\(safeName) \(counter).md")
            counter += 1
        }

        try content.write(to: targetURL, atomically: true, encoding: .utf8)
        return targetURL
    }

    /// 将修改后的外部 Note 内容写回磁盘
    func saveExternalNote(_ note: Note) {
        guard let path = note.externalFilePath else { return }
        let url = URL(fileURLWithPath: path)

        do {
            try note.content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save external note to \(path): \(error.localizedDescription)")
        }
    }
}
