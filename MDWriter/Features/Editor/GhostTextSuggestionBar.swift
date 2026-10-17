//
//  GhostTextSuggestionBar.swift
//  MDWriter
//
//  Floating ghost text suggestion capsule with Tab key acceptance.
//

import SwiftUI

struct GhostTextSuggestionBar: View {
    @ObservedObject var ghostController: GhostTextController
    @ObservedObject var editorController: EditorController

    var body: some View {
        if !ghostController.ghostSuggestion.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(ghostController.ghostSuggestion)
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button {
                    ghostController.accept(into: editorController)
                } label: {
                    HStack(spacing: 3) {
                        Text("Tab ⇥")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text(LocalizedStringKey("Accept"))
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.tab, modifiers: [])

                Button {
                    ghostController.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
}
