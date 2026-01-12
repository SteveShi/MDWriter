//
//  FileSystemModel.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import Foundation
import SwiftUI
import Combine

// 代表文件或文件夹的节点
struct FileItem: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let isDirectory: Bool
    var children: [FileItem]? = nil // 如果是文件夹，这里存子项
    
    var name: String {
        url.lastPathComponent
    }
    
    var modificationDate: Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
    }
}

class FileSystemModel: ObservableObject {
    @Published var rootURL: URL
    @Published var items: [FileItem] = []
    @Published var selectedFolder: URL? // 当前选中的文件夹
    @Published var selectedFile: URL?   // 当前选中的文件
    
    init() {
        // 默认使用 App 沙盒的 Documents 目录
        self.rootURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        
        // 加载根目录
        loadRoot()
    }
    
    func loadRoot() {
        // 重新构建目录树
        if let rootItem = loadFolderTree(from: rootURL) {
            self.items = rootItem.children ?? []
        }
    }
    
    // 递归加载文件夹结构
    func loadFolderTree(from url: URL) -> FileItem? {
        var item = FileItem(url: url, isDirectory: true, children: [])
        
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return item
        }
        
        var children: [FileItem] = []
        for fileURL in contents {
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                if let childDir = loadFolderTree(from: fileURL) {
                    children.append(childDir)
                }
            }
        }
        
        // 排序
        item.children = children.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return item
    }
    
    // 获取指定文件夹内的文件（非递归，用于中间栏）
    func files(in folder: URL) -> [FileItem] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        return contents
            .filter { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return !isDir && (url.pathExtension == "md" || url.pathExtension == "markdown")
            }
            .map { FileItem(url: $0, isDirectory: false) }
            .sorted { $0.modificationDate > $1.modificationDate }
    }
    
    // 重命名
    func renameItem(_ item: FileItem, to newName: String) {
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName + (item.isDirectory ? "" : ".md"))
        try? FileManager.default.moveItem(at: item.url, to: newURL)
        loadRoot()
    }
    
    // 删除
    func deleteItem(_ item: FileItem) {
        try? FileManager.default.removeItem(at: item.url)
        
        // 如果删除的是当前选中的文件/文件夹，清除选中状态
        if selectedFile == item.url { selectedFile = nil }
        if selectedFolder == item.url { selectedFolder = nil }
        loadRoot()
    }

    // 创建新文件
    func createNewFile(in folder: URL) {
        let newURL = folder.appendingPathComponent("Untitled \(Int(Date().timeIntervalSince1970)).md")
        try? "# New Document\n".write(to: newURL, atomically: true, encoding: .utf8)
        loadRoot()
    }
    
    // 创建新文件夹
    func createNewFolder(in folder: URL) {
        let newURL = folder.appendingPathComponent("New Group")
        try? FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
        loadRoot()
    }
    
    // 读取文件内容
    func readFile(_ url: URL) -> String {
        return (try? String(contentsOf: url)) ?? ""
    }
    
    // 保存文件
    func saveFile(_ url: URL, content: String) {
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
