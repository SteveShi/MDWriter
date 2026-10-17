//
//  WhatsNewConfiguration.swift
//  MDWriter
//
//  v3.1 Highlights Sheet Configuration (Keeping v3.0 core + appending v3.1 features)
//

import SwiftUI

struct WhatsNewItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

struct WhatsNewSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String = String(localized: "What's New in MDWriter 4.0")

    let features: [WhatsNewItem] = [
        WhatsNewItem(
            icon: "sparkles",
            title: String(localized: "Inline AI & Diff Review (⌘K)"),
            subtitle: String(
                localized:
                    "Invoke AI directly at cursor with floating command bar and selection capsule. Review line-by-line diffs with deduplicated safety snapshots."
            )
        ),
        WhatsNewItem(
            icon: "link",
            title: String(localized: "Local RAG & [[WikiLinks]]"),
            subtitle: String(
                localized:
                    "Offline paragraph-level semantic search powered by Apple NaturalLanguage, plus bidirectional WikiLinks and backlinks inspector."
            )
        ),
        WhatsNewItem(
            icon: "text.viewfinder",
            title: String(localized: "Vision OCR & Ghost Text"),
            subtitle: String(
                localized:
                    "On-device Vision OCR for images/PDFs and proactive real-time inline ghost text predictions accepted with a single Tab key."
            )
        ),
        WhatsNewItem(
            icon: "folder.badge.gearshape",
            title: String(localized: "External Folders & Quick Entry"),
            subtitle: String(
                localized:
                    "Mount local Markdown folders with direct disk sync, and capture quick thoughts via the menu bar popover (⌥⇧N)."
            )
        ),
        WhatsNewItem(
            icon: "function",
            title: String(localized: "LaTeX & Mermaid Rendering"),
            subtitle: String(
                localized:
                    "Native KaTeX mathematical formula rendering, Mermaid diagram visual generation, and multi-document combined book export."
            )
        ),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(features) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22))
                            .foregroundColor(.accentColor)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                            Text(item.subtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            Button(action: { dismiss() }) {
                Text(LocalizedStringKey("Continue"))
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 530)
    }
}
