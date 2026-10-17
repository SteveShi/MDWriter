//
//  InlineAICommandBar.swift
//  MDWriter
//
//  Floating command input bar and quick action pills for inline AI editing.
//

import SwiftUI

struct InlineAICommandBar: View {
    @ObservedObject var inlineController: InlineAIController
    @ObservedObject var editorController: EditorController
    var note: Note?
    @Environment(\.modelContext) private var modelContext

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Input Field Row
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                TextField(
                    inlineController.originalText.isEmpty
                        ? LocalizedStringKey("Ask AI to write, brainstorm, or outline...")
                        : LocalizedStringKey("Ask AI to edit, polish, or rewrite selection..."),
                    text: $inlineController.userPrompt
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .focused($isInputFocused)
                .onSubmit {
                    submitCurrentInput()
                }

                if inlineController.state == .generating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)

                        Button {
                            inlineController.hide(controller: editorController)
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(LocalizedStringKey("Stop generation (Esc)"))
                    }
                } else {
                    if !inlineController.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            submitCurrentInput()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help(LocalizedStringKey("Submit (⏎)"))
                    } else {
                        Button {
                            inlineController.hide(controller: editorController)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help(LocalizedStringKey("Close (Esc)"))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(10)

            // MARK: - Selection Context Indicator
            if !inlineController.originalText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "selection.pin.in.out")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    let snippet = inlineController.originalText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32)
                    Text("\"\(snippet)\(inlineController.originalText.count > 32 ? "..." : "")\"")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("(\(inlineController.originalText.count) chars)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Button {
                        // Clear selection binding and switch to cursor insertion
                        withAnimation {
                            inlineController.originalText = ""
                            inlineController.originalRange = NSRange(location: inlineController.originalRange.location, length: 0)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("Detach selection"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(6)
            }

            // MARK: - Preset Action Pills
            if inlineController.state == .input {
                actionPillsView
            }

            // MARK: - Thinking Preview (during generation)
            if inlineController.state == .generating && !inlineController.reasoningText.isEmpty {
                DisclosureGroup(
                    isExpanded: $inlineController.isThinkingExpanded,
                    content: {
                        ScrollView {
                            Text(inlineController.reasoningText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 120)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(6)
                    },
                    label: {
                        HStack(spacing: 5) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 11))
                            Text(LocalizedStringKey("Thinking..."))
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                )
            }

            // MARK: - Error Banner
            if let error = inlineController.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .onAppear {
            isInputFocused = true
        }
    }

    // MARK: - Action Pills View

    private var actionPillsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let actions = InlineAIAction.allCases.filter { action in
                    if inlineController.originalText.isEmpty {
                        return !action.requiresSelection
                    } else {
                        return true
                    }
                }

                ForEach(actions) { action in
                    Button {
                        inlineController.submit(
                            action: action,
                            note: note,
                            controller: editorController,
                            modelContext: modelContext
                        )
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: action.icon)
                                .font(.system(size: 10))
                            Text(LocalizedStringKey(action.titleKey))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.08))
                        .foregroundStyle(.primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func submitCurrentInput() {
        let trimmed = inlineController.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inlineController.submit(
            prompt: trimmed,
            note: note,
            controller: editorController,
            modelContext: modelContext
        )
    }
}
