//
//  SettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var editorSettings = EditorSettings.shared

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(LocalizedStringKey("General"), systemImage: "gearshape")
                }
                .tag(1)
            
            EditorSettingsView(settings: editorSettings)
                .tabItem {
                    Label(LocalizedStringKey("Editor"), systemImage: "doc.text")
                }
                .tag(2)
            
            MarkdownSettingsView()
                .tabItem {
                    Label(LocalizedStringKey("Markdown"), systemImage: "text.quote")
                }
                .tag(3)

            AISettingsView()
                .tabItem {
                    Label(LocalizedStringKey("AI"), systemImage: "apple.intelligence")
                }
                .tag(4)
        }
        .frame(width: 550, height: 450)
    }
}
