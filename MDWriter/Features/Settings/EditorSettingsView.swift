//
//  EditorSettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import MDEditorKit
import SwiftUI

struct EditorSettingsView: View {
    @ObservedObject var settings: EditorSettings

    var body: some View {
        Form {
            // Typography Section
            Section {
                Grid(alignment: .leading, verticalSpacing: 10) {
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
                }

                Toggle(LocalizedStringKey("Outdent Syntax Markers"), isOn: $settings.outdentSyntaxMarkers)
                    .help(LocalizedStringKey("Hangs heading and list markers into the left margin so body text aligns cleanly."))
            } header: {
                Text(LocalizedStringKey("Layout"))
            }

            // Behavior & Focus Section
            Section {
                Picker(LocalizedStringKey("Focus Mode"), selection: $settings.focusMode) {
                    Text(LocalizedStringKey("Off")).tag(EditorFocusMode.off)
                    Text(LocalizedStringKey("Sentence")).tag(EditorFocusMode.sentence)
                    Text(LocalizedStringKey("Paragraph")).tag(EditorFocusMode.paragraph)
                }
                .pickerStyle(.segmented)

                Toggle(LocalizedStringKey("Highlight Current Line"), isOn: $settings.highlightCurrentLine)

                Toggle(LocalizedStringKey("Typewriter Mode"), isOn: $settings.typewriterMode)
                    .help(LocalizedStringKey("Keeps the active line anchored vertically while typing."))

                if settings.typewriterMode {
                    Picker(LocalizedStringKey("Typewriter Position"), selection: $settings.typewriterAnchor) {
                        Text(LocalizedStringKey("Top")).tag(TypewriterAnchor.top)
                        Text(LocalizedStringKey("Center")).tag(TypewriterAnchor.center)
                        Text(LocalizedStringKey("Bottom")).tag(TypewriterAnchor.bottom)
                    }
                    .pickerStyle(.segmented)
                }

                Toggle(LocalizedStringKey("Render LaTeX Math Inline"), isOn: $settings.renderMathInline)
                    .help(LocalizedStringKey("Typesets $...$ and $$...$$ LaTeX equations natively in the editor."))
            } header: {
                Text(LocalizedStringKey("View Options"))
            }
        }
        .formStyle(.grouped)
    }
}
