//
//  ChatInputView.swift
//  MDWriter
//

import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    var isProcessing: Bool
    var onSend: () -> Void
    var onCancel: () -> Void
    @ObservedObject var controller: EditorController
    var note: Note?

    var body: some View {
        VStack(spacing: 8) {
            // Context Quick Attach Pills
            HStack(spacing: 8) {
                Button {
                    if let sel = controller.proxy.getSelectedText(), !sel.isEmpty {
                        text += "\n[Selected Text Context:\n\(sel)\n]"
                    }
                } label: {
                    Label(LocalizedStringKey("Selected Text"), systemImage: "selection.pin.in.out")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    if let content = note?.content, !content.isEmpty {
                        text += "\n[Document Content Context:\n\(content)\n]"
                    }
                } label: {
                    Label(LocalizedStringKey("Full Document"), systemImage: "doc.text")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }

            // Input Area
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .frame(minHeight: 36, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                if isProcessing {
                    Button(action: onCancel) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }
}
