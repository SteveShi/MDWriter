//
//  MDWriterApp.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct MDWriterApp: App {
    // Sparkle Updater
    @StateObject private var updater = Updater()

    // Manual WhatsNew State
    @State private var showWhatsNewSheet: Bool = false

    // 全局视图状态 (用于菜单命令)
    @AppStorage("showLibrary") var showLibrary: Bool = true
    @AppStorage("showOutline") var showOutline: Bool = false
    @AppStorage("textZoom") var textZoom: Double = 1.0

    @AppStorage("appTheme") private var currentTheme: AppTheme = .light

    @Environment(\.scenePhase) private var scenePhase

    // 显式管理 ModelContainer 以确保稳定性
    let container: ModelContainer

    init() {
        do {
            // 获取或创建 Application Support/MDWriter 目录，确保非沙盒及未签名状态下的数据稳定性
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!
            let dataFolderURL = appSupportURL.appendingPathComponent("MDWriter", isDirectory: true)

            if !fileManager.fileExists(atPath: dataFolderURL.path) {
                try? fileManager.createDirectory(
                    at: dataFolderURL, withIntermediateDirectories: true)
            }

            let sqliteURL = dataFolderURL.appendingPathComponent("library.sqlite")

            let schema = Schema([Folder.self, Note.self, Snapshot.self, Memo.self, ChatMessage.self])
            let config = ModelConfiguration(url: sqliteURL, allowsSave: true)

            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("MDWriter", id: "main") {
            LibraryView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(currentTheme.colorScheme)
                .sheet(isPresented: $showWhatsNewSheet) {
                    WhatsNewSheetView()
                }
                .onReceive(NotificationCenter.default.publisher(for: .showWhatsNew)) { _ in
                    showWhatsNewSheet = true
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase != .active {
                        saveMainContext()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    saveMainContext()
                }
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: ["*"])
        .commands {
            // ... (keep original commands)
            CommandGroup(after: .appInfo) {
                Button(LocalizedStringKey("Check for Updates...")) {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
            FileCommands()
            EditCommands()
            ViewCommands(
                showLibrary: $showLibrary,
                showDashboard: $showOutline,
                showOutline: $showOutline,
                textZoom: Binding(get: { CGFloat(textZoom) }, set: { textZoom = Double($0) }),
                currentTheme: $currentTheme
            )
            FormatCommands()
            HelpCommands()
        }

        #if os(macOS)
            Settings {
                SettingsView()
                    .preferredColorScheme(currentTheme.colorScheme)
            }
        #endif
    }

    @MainActor
    private func saveMainContext() {
        do {
            try container.mainContext.save()
        } catch {
            print("Global save failed: \(error)")
        }
    }
}
