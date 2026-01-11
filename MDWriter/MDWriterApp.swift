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
    // 初始化 AppUpdater
    // 注意：请将 'owner' 和 'repo' 替换为您实际的 GitHub 用户名和仓库名
    @StateObject var appUpdater = AppUpdater(
        owner: "lpgneg19", // 替换为您的 GitHub 用户名
        repo: "MDWriter",      // 替换为您的仓库名
        interval: 86400      // 自动检查频率 (每天)
    )

    var body: some Scene {
        DocumentGroup(newDocument: MDWriterDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            // 在应用菜单 (MDWriter) 中添加 "Check for Updates..."
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    appUpdater.check()
                }
            }
        }
    }
}
