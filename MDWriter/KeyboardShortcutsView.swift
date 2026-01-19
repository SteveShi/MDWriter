//
//  KeyboardShortcutsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(LocalizedStringKey("Keyboard Shortcuts"))
                    .font(.headline)
                Spacer()
                Button(LocalizedStringKey("Done")) {
                    dismiss()
                }
            }
            .padding()
            .background(Color.platformBackground)

            Divider()

            // Shortcuts List
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ShortcutSection(
                        title: "File",
                        shortcuts: [
                            ("New Sheet", "⌘N"),
                            ("New Group", "⇧⌘N"),
                            ("Import...", "⇧⌘I"),
                            ("Print...", "⌘P"),
                        ])

                    ShortcutSection(
                        title: "Edit",
                        shortcuts: [
                            ("Find...", "⌘F"),
                            ("Find & Replace...", "⌥⌘F"),
                            ("Find Next", "⌘G"),
                            ("Find Previous", "⇧⌘G"),
                        ])

                    ShortcutSection(
                        title: "View",
                        shortcuts: [
                            ("Show/Hide Library", "⌘1"),
                            ("Show/Hide Sheet List", "⌘2"),
                            ("Show/Hide Dashboard", "⌘4"),
                            ("Show/Hide Preview", "⇧⌘P"),
                            ("Show/Hide Outline", "⌥⌘O"),
                            ("Zoom In", "⌘+"),
                            ("Zoom Out", "⌘-"),
                            ("Actual Size", "⌘0"),
                        ])

                    ShortcutSection(
                        title: "Format",
                        shortcuts: [
                            ("Heading 1-6", "⌃⌘1-6"),
                            ("Bold", "⌘B"),
                            ("Italic", "⌘I"),
                            ("Strikethrough", "⌃⌘U"),
                            ("Highlight", "⌃⌘H"),
                            ("Review Mode", "⇧⌘R"),
                            ("Lists", "⌘L / ⇧⌘L / ⌥⌘L"),
                            ("Blockquote", "⌘'"),
                            ("Code Block", "⌘K"),
                            ("Inline Code", "⇧⌘K"),
                            ("Link", "⌥⌘K"),
                            ("Image", "⇧⌘I"),
                            ("Horizontal Rule", "⇧⌘-"),
                        ])
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct ShortcutSection: View {
    let title: LocalizedStringKey
    let shortcuts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                ForEach(shortcuts, id: \.0) { item in
                    GridRow {
                        Text(LocalizedStringKey(item.0))
                            .foregroundStyle(.primary)

                        Text(item.1)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
        }
    }
}

#Preview {
    KeyboardShortcutsView()
}
