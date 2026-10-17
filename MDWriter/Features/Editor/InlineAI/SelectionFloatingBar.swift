//
//  SelectionFloatingBar.swift
//  MDWriter
//
//  Compact floating toolbar displayed near text selections for one-click AI enhancements.
//

import SwiftUI

struct SelectionFloatingBar: View {
    @ObservedObject var editorController: EditorController
    @ObservedObject var inlineController: InlineAIController
    var note: Note?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 4) {
            // Main trigger pill
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    inlineController.show(from: editorController)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("AI (⌘K)")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 14)

            // One-click quick actions
            Button {
                inlineController.show(from: editorController)
                inlineController.submit(
                    action: .polish,
                    note: note,
                    controller: editorController,
                    modelContext: modelContext
                )
            } label: {
                Text(LocalizedStringKey("Polish"))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button {
                inlineController.show(from: editorController)
                inlineController.submit(
                    action: .shorten,
                    note: note,
                    controller: editorController,
                    modelContext: modelContext
                )
            } label: {
                Text(LocalizedStringKey("Shorten"))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Button {
                inlineController.show(from: editorController)
                inlineController.submit(
                    action: .translate,
                    note: note,
                    controller: editorController,
                    modelContext: modelContext
                )
            } label: {
                Text(LocalizedStringKey("Translate"))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}
