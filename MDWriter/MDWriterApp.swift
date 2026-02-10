//
//  MDWriterApp.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import Foundation
import SwiftData
import SwiftUI
import WhatsNewKit

@main
struct MDWriterApp: App {
    // Sparkle Updater
    @StateObject private var updater = Updater()

    // Manual WhatsNew State
    @State private var manualWhatsNew: WhatsNew?

    // 全局视图状态 (用于菜单命令)
    @AppStorage("showLibrary") var showLibrary: Bool = true
    @AppStorage("showDashboard") var showDashboard: Bool = false
    @AppStorage("showOutline") var showOutline: Bool = false
    @AppStorage("textZoom") var textZoom: Double = 1.0

    @AppStorage("appTheme") private var currentTheme: AppTheme = .light

    var body: some Scene {
        // 使用 WindowGroup 替代 DocumentGroup
        WindowGroup("MDWriter", id: "main") {
            LibraryView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(currentTheme.colorScheme)
                .environment(
                    \.whatsNew,
                    WhatsNewEnvironment(
                        currentVersion: WhatsNewConfiguration.appVersion,
                        whatsNewCollection: [WhatsNewConfiguration.current]
                    )
                )
                .whatsNewSheet()
                .sheet(item: $manualWhatsNew) { whatsNew in
                    WhatsNewView(whatsNew: whatsNew)
                }
                .onReceive(NotificationCenter.default.publisher(for: .showWhatsNew)) { _ in
                    manualWhatsNew = WhatsNewConfiguration.current
                }

        }
        // 使用 SwiftData 默认存储：自动处理路径、目录创建和持久化
        .modelContainer(for: [Folder.self, Note.self, Snapshot.self, Memo.self])
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: ["*"])
        .commands {
            // App Info Commands (Updates)
            CommandGroup(after: .appInfo) {
                Button(LocalizedStringKey("Check for Updates...")) {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }

            // File Commands
            FileCommands()

            // Edit Commands (Find/Replace)
            EditCommands()

            // View Commands
            ViewCommands(
                showLibrary: $showLibrary,
                showDashboard: $showDashboard,
                showOutline: $showOutline,
                textZoom: Binding(
                    get: { CGFloat(textZoom) },
                    set: { textZoom = Double($0) }
                ),
                currentTheme: $currentTheme
            )

            // Format Commands
            FormatCommands()

            // Help Commands
            HelpCommands()
        }

        // Settings Window
        #if os(macOS)
            Settings {
                SettingsView()
                    .preferredColorScheme(currentTheme.colorScheme)
            }
        #endif
    }
}
