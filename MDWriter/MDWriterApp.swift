//
//  MDWriterApp.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import SwiftData
import SwiftUI

@main
struct MDWriterApp: App {
    // 全局视图状态 (用于菜单命令)
    @AppStorage("showLibrary") var showLibrary: Bool = true
    @AppStorage("showDashboard") var showDashboard: Bool = false
    @AppStorage("showOutline") var showOutline: Bool = false
    @AppStorage("textZoom") var textZoom: Double = 1.0

    @AppStorage("appTheme") private var currentTheme: AppTheme = .light

    var body: some Scene {
        // 使用 WindowGroup 替代 DocumentGroup
        WindowGroup {
            LibraryView()
                .preferredColorScheme(currentTheme.colorScheme)
                .modelContainer(for: [Folder.self, Note.self])
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
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
