//
//  MDWriterApp.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import SwiftUI
import AppUpdater

@main
struct MDWriterApp: App {
    // 保持更新器
    @StateObject var appUpdater = AppUpdater(
        owner: "steve",
        repo: "MDWriter",
        interval: 86400
    )
    
    // 全局文件系统模型
    @StateObject var fileSystem = FileSystemModel()

    var body: some Scene {
        // 使用 WindowGroup 替代 DocumentGroup
        WindowGroup {
            LibraryView()
                .environmentObject(fileSystem)
        }
        .commands {
            // 添加菜单命令
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    appUpdater.check()
                }
            }
            
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    if let selectedFolder = fileSystem.selectedFolder {
                        fileSystem.createNewFile(in: selectedFolder)
                    } else {
                        fileSystem.createNewFile(in: fileSystem.rootURL)
                    }
                }
                .keyboardShortcut("n")
                
                Button("New Group") {
                     if let selectedFolder = fileSystem.selectedFolder {
                         fileSystem.createNewFolder(in: selectedFolder)
                     } else {
                         fileSystem.createNewFolder(in: fileSystem.rootURL)
                     }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}