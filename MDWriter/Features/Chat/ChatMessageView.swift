//
//  ChatMessageView.swift
//  MDWriter
//

import SwiftUI

/// Parses `<think>...</think>` blocks from LLM streaming or persisted content.
struct ThinkingContentParser {
    struct ParsedContent {
        let thinking: String?
        let answer: String
        let isThinkingInProgress: Bool
    }

    static func parse(_ raw: String) -> ParsedContent {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<think>") else {
            return ParsedContent(thinking: nil, answer: raw, isThinkingInProgress: false)
        }

        let afterOpen = String(trimmed.dropFirst("<think>".count))
        if let closeRange = afterOpen.range(of: "</think>") {
            let thought = String(afterOpen[..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = String(afterOpen[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedContent(
                thinking: thought.isEmpty ? nil : thought,
                answer: answer,
                isThinkingInProgress: false
            )
        } else {
            let thought = afterOpen.trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedContent(
                thinking: thought,
                answer: "",
                isThinkingInProgress: true
            )
        }
    }
}

/// Collapsible card displaying the model's step-by-step reasoning process.
struct ThinkingBlockView: View {
    let thinkingText: String
    var isStreaming: Bool = false
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    Text(LocalizedStringKey(isStreaming ? "Thinking..." : "Thought Process"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded || isStreaming {
                Text(thinkingText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
        )
    }
}

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
        let parsed = ThinkingContentParser.parse(message.content)
        let cleanAnswer = parsed.answer.isEmpty ? message.content : parsed.answer

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text(message.modelName ?? "Assistant")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let thinking = parsed.thinking, !thinking.isEmpty {
                ThinkingBlockView(thinkingText: thinking, isStreaming: parsed.isThinkingInProgress)
            }

            if !parsed.answer.isEmpty || parsed.thinking == nil {
                Text(parsed.answer.isEmpty ? message.content : parsed.answer)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }

            // Action buttons for Assistant text (always copy/insert clean answer without <think>)
            HStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cleanAnswer, forType: .string)
                } label: {
                    Label(LocalizedStringKey("Copy"), systemImage: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)

                Button {
                    controller.proxy.insert(cleanAnswer)
                } label: {
                    Label(LocalizedStringKey("Replace Selection"), systemImage: "arrow.turn.down.left")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)

                Button {
                    controller.proxy.insert(cleanAnswer)
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
