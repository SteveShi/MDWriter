//
//  MDWriterApp.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import AppUpdater
import SwiftData
import SwiftUI

@main
struct MDWriterApp: App {
    // 保持更新器
    @StateObject var appUpdater = AppUpdater(
        owner: "lpgneg19",
        repo: "MDWriter",
        interval: 86400
    )

    // 全局视图状态 (用于菜单命令)
    @AppStorage("showLibrary") var showLibrary: Bool = true
    @AppStorage("showDashboard") var showDashboard: Bool = false
    @AppStorage("showPreview") var showPreview: Bool = false
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
            // App Menu
            CommandGroup(after: .appInfo) {
                Button(LocalizedStringKey("Check for Updates...")) {
                    appUpdater.check()
                }
            }

            // File Commands
            FileCommands()

            // Edit Commands (Find/Replace)
            EditCommands()

            // View Commands
            ViewCommands(
                showLibrary: $showLibrary,
                showDashboard: $showDashboard,
                showPreview: $showPreview,
                showOutline: $showOutline,
                textZoom: Binding(
                    get: { CGFloat(textZoom) },
                    set: { textZoom = Double($0) }
                )
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

// MARK: - Settings View (Placeholder)
struct SettingsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .light
    @StateObject private var typography = TypographySettings()

    var body: some View {
        TabView {
            GeneralSettingsView(typography: typography)
                .tabItem {
                    Label(LocalizedStringKey("General"), systemImage: "gear")
                }

            AppearanceSettingsView(currentTheme: $currentTheme)
                .tabItem {
                    Label(LocalizedStringKey("Appearance"), systemImage: "paintbrush")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var typography: TypographySettings

    var body: some View {
        Form {
            Section(LocalizedStringKey("Editor")) {
                Picker(LocalizedStringKey("Font"), selection: $typography.fontName) {
                    ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                HStack {
                    Text(LocalizedStringKey("Font Size"))
                    Slider(value: $typography.fontSize, in: 12...24, step: 1)
                    Text("\(Int(typography.fontSize))")
                        .frame(width: 30)
                }

                HStack {
                    Text(LocalizedStringKey("Line Height"))
                    Slider(value: $typography.lineHeightMultiple, in: 1.2...2.0, step: 0.1)
                    Text(String(format: "%.1f", typography.lineHeightMultiple))
                        .frame(width: 30)
                }
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @Binding var currentTheme: AppTheme

    var body: some View {
        Form {
            Section(LocalizedStringKey("Theme")) {
                Picker(LocalizedStringKey("Appearance"), selection: $currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(LocalizedStringKey(theme.rawValue), systemImage: theme.icon)
                            .tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .padding()
    }
}
