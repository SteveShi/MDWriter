//
//  ChatMessageView.swift
//  MDWriter
//

import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    @ObservedObject var controller: EditorController

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 40)
                userBubble
            } else if message.role == "tool" {
                ChatToolResultView(toolName: message.toolName, content: message.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                assistantBubble
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(12)
        }
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text(message.modelName ?? "Assistant")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(message.content)
                .font(.system(size: 13))
                .lineSpacing(3)
                .textSelection(.enabled)

            // Action buttons for Assistant text
            HStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.content, forType: .string)
                } label: {
                    Label(LocalizedStringKey("Copy"), systemImage: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)

                Button {
                    controller.proxy.insert(message.content)
                } label: {
                    Label(LocalizedStringKey("Replace Selection"), systemImage: "arrow.turn.down.left")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)

                Button {
                    controller.proxy.insert(message.content)
                } label: {
                    Label(LocalizedStringKey("Insert"), systemImage: "text.insert")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}
