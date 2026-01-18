//
//  GeneralSettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .light
    @AppStorage("showDashboard") private var showDashboard: Bool = false
    @AppStorage("showLibrary") private var showLibrary: Bool = true
    @AppStorage("SUEnableAutomaticChecks") private var automaticallyCheckForUpdates: Bool = true
    
    var body: some View {
        Form {
            // Section 1: Appearance
            Section {
                Picker(LocalizedStringKey("Appearance:"), selection: $currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(LocalizedStringKey(theme.rawValue)).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                
            } header: {
                Text(LocalizedStringKey("Appearance"))
            } footer: {
                Text(LocalizedStringKey("Choose the look and feel of the application interface."))
            }
            
            // Section 2: Sidebar & Panels
            Section(header: Text(LocalizedStringKey("Sidebar & Panels"))) {
                Toggle(LocalizedStringKey("Show Library Sidebar by default"), isOn: $showLibrary)
                Toggle(LocalizedStringKey("Show Statistics Dashboard"), isOn: $showDashboard)
            }

            // Section 3: Updates
            Section(header: Text(LocalizedStringKey("Updates"))) {
                Toggle(LocalizedStringKey("Automatically check for updates"), isOn: $automaticallyCheckForUpdates)
            }
        }
        .formStyle(.grouped)
    }
}