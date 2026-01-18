//
//  EditorSettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI

struct EditorSettingsView: View {
    @ObservedObject var settings: EditorSettings
    
    var body: some View {
        Form {
            // Typography Section
            Section {
                Grid(alignment: .leading, verticalSpacing: 10) {
                    // Font Family
                    GridRow {
                        Text(LocalizedStringKey("Font:"))
                            .gridColumnAlignment(.trailing)
                        Picker("", selection: $settings.fontName) {
                            Text(LocalizedStringKey("System Font")).tag("System")
                            Divider()
                            ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { font in
                                Text(font).tag(font)
                                    .font(.custom(font, size: 12))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Line Height
                    GridRow {
                        Text(LocalizedStringKey("Line Height:"))
                        HStack {
                            Slider(value: $settings.lineHeightMultiple, in: 1.0...3.0, step: 0.1)
                            Text(String(format: "%.1f", settings.lineHeightMultiple))
                                .monospacedDigit()
                                .frame(width: 45, alignment: .trailing)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(LocalizedStringKey("Typography"))
            }
            
            // Layout Section
            Section {
                Grid(alignment: .leading, verticalSpacing: 10) {
                    // Line Width
                    GridRow {
                        Text(LocalizedStringKey("Line Width:"))
                            .gridColumnAlignment(.trailing)
                        HStack {
                            Slider(value: $settings.contentWidth, in: 400...1200, step: 50)
                            Text("\(Int(settings.contentWidth)) px")
                                .monospacedDigit()
                                .frame(width: 55, alignment: .trailing)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Paragraph Spacing
                    GridRow {
                        Text(LocalizedStringKey("Par. Space:"))
                        HStack {
                            Slider(value: $settings.paragraphSpacing, in: 0...50, step: 2)
                            Text("\(Int(settings.paragraphSpacing)) pt")
                                .monospacedDigit()
                                .frame(width: 55, alignment: .trailing)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // First Line Indent
                    GridRow {
                        Text(LocalizedStringKey("Indent:"))
                        HStack {
                            Slider(value: $settings.firstLineIndent, in: 0...100, step: 5)
                            Text("\(Int(settings.firstLineIndent)) pt")
                                .monospacedDigit()
                                .frame(width: 55, alignment: .trailing)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text(LocalizedStringKey("Layout"))
            }
            
            // Behavior Section
            Section {
                Toggle(LocalizedStringKey("Typewriter Mode"), isOn: $settings.typewriterMode)
                    .help(LocalizedStringKey("Keeps the cursor centered vertically in the editor."))
            } header: {
                Text(LocalizedStringKey("View Options"))
            }
        }
        .formStyle(.grouped)
    }
}
