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

    let title: String = String(localized: "What's New in MDWriter 3.1")

    let features: [WhatsNewItem] = [
        WhatsNewItem(
            icon: "cpu.fill",
            title: String(localized: "Local LLM Engines"),
            subtitle: String(
                localized:
                    "Connect to Ollama, LM Studio, oMLX, llama.cpp, MLX, and Jan with complete privacy and zero cloud uploads."
            )
        ),
        WhatsNewItem(
            icon: "bubble.left.and.bubble.right.fill",
            title: String(localized: "AI Chat & Tool Calling"),
            subtitle: String(
                localized:
                    "Chat with AI to edit selections, manage library notes, update metadata, or format Markdown tables."
            )
        ),
        WhatsNewItem(
            icon: "network",
            title: String(localized: "Model Context Protocol (MCP)"),
            subtitle: String(
                localized:
                    "Extend AI with local filesystem access, web fetch, Puppeteer, and custom stdio server tools."
            )
        ),
        WhatsNewItem(
            icon: "lock.shield.fill",
            title: String(localized: "Encrypted Backup & Dropbox Sync"),
            subtitle: String(
                localized:
                    "AES-256 encrypted library backups (.mdwbk) and zero-knowledge E2EE Dropbox cloud synchronization."
            )
        ),
        WhatsNewItem(
            icon: "textformat.italic",
            title: String(localized: "CJK Italic & Export Alignment"),
            subtitle: String(
                localized:
                    "Native obliqueness slant for Chinese italic text and 100% line break alignment in PDF/HTML exports."
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
