//
//  WhatsNewConfiguration.swift
//  MDWriter
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

    let title: String = String(localized: "What's New in MDWriter")

    let features: [WhatsNewItem] = [
        WhatsNewItem(
            icon: "apple.intelligence",
            title: String(localized: "Apple Intelligence"),
            subtitle: String(
                localized:
                    "Harness the power of on-device AI for polishing, summarizing, translating, and smart tagging."
            )
        ),
        WhatsNewItem(
            icon: "cpu",
            title: String(localized: "TextKit 2 Engine"),
            subtitle: String(
                localized:
                    "A complete overhaul of the editor core for massive stability and performance gains."
            )
        ),
        WhatsNewItem(
            icon: "paintpalette",
            title: String(localized: "Pro Markdown Rendering"),
            subtitle: String(
                localized:
                    "Ulysses-style syntax highlighting with elegant faders for a distraction-free experience."
            )
        ),
        WhatsNewItem(
            icon: "keyboard",
            title: String(localized: "IME Stability"),
            subtitle: String(
                localized:
                    "Native support for Chinese input and mixed-language writing without cursor jumping."
            )
        ),
        WhatsNewItem(
            icon: "photo",
            title: String(localized: "Inline Image Preview"),
            subtitle: String(
                localized:
                    "View your local images directly inside the editor and export previews with ease."
            )
        ),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(features) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: item.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)

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
        .frame(width: 480, height: 500)
    }
}
