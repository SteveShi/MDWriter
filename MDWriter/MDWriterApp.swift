//
//  MDWriterApp.swift
//  MDWriter
//
//  Created by 石屿 on 2025/12/31.
//

import SwiftData
import SwiftUI
import WhatsNewKit

@main
struct MDWriterApp: App {
    // Sparkle Updater (macOS only)
    #if os(macOS)
    @StateObject private var updater = Updater()
    #endif
    
    // Manual WhatsNew State (Available on all platforms)
    @State private var manualWhatsNew: WhatsNew?
    
    @AppStorage("showLibrary") var showLibrary: Bool = true
    @AppStorage("showDashboard") var showDashboard: Bool = false
    @AppStorage("showOutline") var showOutline: Bool = false
    @AppStorage("textZoom") var textZoom: Double = 1.0
    @AppStorage("appTheme") private var currentTheme: AppTheme = .light

    var body: some Scene {
        WindowGroup("MDWriter", id: "main") {
            LibraryView()
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
                #endif
                .preferredColorScheme(currentTheme.colorScheme)
                .modelContainer(for: [Folder.self, Note.self])
                .environment(
                    \.whatsNew,
                    WhatsNewEnvironment(
                        currentVersion: WhatsNewConfiguration.current.version,
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
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
        .handlesExternalEvents(matching: ["*"])
        .commands {
            #if os(macOS)
            CommandGroup(after: .appInfo) {
                Button(LocalizedStringKey("Check for Updates...")) {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
            #endif
            
            FileCommands()
            EditCommands()

            ViewCommands(
                showLibrary: $showLibrary,
                showDashboard: $showDashboard,
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
}