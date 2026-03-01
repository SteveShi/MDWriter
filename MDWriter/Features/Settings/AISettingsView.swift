//
//  AISettingsView.swift
//  MDWriter
//
//  AI settings panel for preferences window.
//

import SwiftUI

struct AISettingsView: View {
    @AppStorage("aiEnabled") private var aiEnabled: Bool = true
    @AppStorage("aiTranslationTarget") private var translationTarget: String = "auto"

    var body: some View {
        Form {
            Section {
                Toggle(LocalizedStringKey("Enable AI Features"), isOn: $aiEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("AI features use Apple Intelligence for on-device processing. No data is sent to the cloud."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(LocalizedStringKey("Apple Intelligence"), systemImage: "apple.intelligence")
            }

            Section {
                Picker(LocalizedStringKey("Translation Target Language"), selection: $translationTarget) {
                    Text(LocalizedStringKey("Auto Detect")).tag("auto")
                    Divider()
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                }
                .pickerStyle(.menu)
            } header: {
                Label(LocalizedStringKey("Translation"), systemImage: "globe")
            }

            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                Section {
                    statusRow
                } header: {
                    Label(LocalizedStringKey("Status"), systemImage: "info.circle")
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .frame(width: 450)
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    @ViewBuilder
    private var statusRow: some View {
        let service = AIService()
        HStack {
            Text(LocalizedStringKey("Apple Intelligence"))
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(service.isAvailable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(service.availabilityDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif
}
