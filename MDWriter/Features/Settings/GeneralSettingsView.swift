//
//  GeneralSettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .system
    @AppStorage("showOutline") private var showOutline: Bool = false
    @AppStorage("showLibrary") private var showLibrary: Bool = true
    @AppStorage("SUEnableAutomaticChecks") private var automaticallyCheckForUpdates: Bool = true
    
    var body: some View {
        Form {
            // Section 1: Appearance
            Section {
                Picker(LocalizedStringKey("Appearance:"), selection: $currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.localizedName, systemImage: theme.icon).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
            } header: {
                Text(LocalizedStringKey("Appearance"))
            } footer: {
                Text(LocalizedStringKey("System automatically adapts both the interface and every editor color scheme to macOS Light and Dark Mode."))
            }
            
            // Section 2: Sidebar & Panels
            Section(header: Text(LocalizedStringKey("Sidebar & Panels"))) {
                Toggle(LocalizedStringKey("Show Library Sidebar by default"), isOn: $showLibrary)
                Toggle(LocalizedStringKey("Show Statistics Dashboard"), isOn: $showOutline)
            }

            // Section 3: Updates
            Section(header: Text(LocalizedStringKey("Updates"))) {
                Toggle(LocalizedStringKey("Automatically check for updates"), isOn: $automaticallyCheckForUpdates)
            }
        }
        .formStyle(.grouped)
    }
}