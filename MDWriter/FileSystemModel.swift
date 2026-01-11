//
//  FileSystemModel.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import Foundation
import SwiftUI

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
        self.items = loadContents(of: rootURL)
    }
    
    // 递归或单层加载内容
    private func loadContents(of url: URL) -> [FileItem] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        var fileItems: [FileItem] = []
        
        for itemURL in contents {
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            
            // 如果是文件夹，我们可以选择是否递归加载。为了性能，通常懒加载。
            // 这里为了简单，我们只构建一层，或者构建树。
            // 针对“三栏布局”，通常左侧只显示文件夹。
            
            if isDir {
                fileItems.append(FileItem(url: itemURL, isDirectory: true))
            } else {
                if itemURL.pathExtension == "md" || itemURL.pathExtension == "markdown" {
                    fileItems.append(FileItem(url: itemURL, isDirectory: false))
                }
            }
        }
        
        // 排序：文件夹在前，然后按修改时间
        return fileItems.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory
            }
            return $0.name < $1.name
        }
    }
    
    // 获取指定文件夹内的所有 MD 文件
    func files(in folder: URL) -> [FileItem] {
        let allItems = loadContents(of: folder)
        return allItems.filter { !$0.isDirectory }
    }
    
    // 获取子文件夹
    func subfolders(in folder: URL) -> [FileItem] {
        let allItems = loadContents(of: folder)
        return allItems.filter { $0.isDirectory }
    }
    
    // 创建新文件
    func createNewFile(in folder: URL) {
        let newURL = folder.appendingPathComponent("Untitled \(Int(Date().timeIntervalSince1970)).md")
        try? "# New Document".write(to: newURL, atomically: true, encoding: .utf8)
        self.objectWillChange.send() // 刷新 UI
    }
    
    // 创建新文件夹
    func createNewFolder(in folder: URL) {
        let newURL = folder.appendingPathComponent("New Group")
        try? FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
        self.objectWillChange.send()
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
