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

    @AppStorage("aiThinkingEnabled") private var isThinkingEnabled: Bool = false
    @AppStorage("searchEnabled") private var searchEnabled: Bool = true
    @AppStorage("mcpToolsEnabled") private var mcpToolsEnabled: Bool = true
    @AppStorage("aiContextLevel") private var contextLevelRaw: String = AIContextLevel.metadata.rawValue

    private var currentContextLevel: AIContextLevel {
        AIContextLevel(rawValue: contextLevelRaw) ?? .metadata
    }

    var body: some View {
        VStack(spacing: 8) {
            // Quick Control Toggles Bar
            HStack(spacing: 6) {
                // Thinking Toggle
                TogglePill(
                    icon: "brain",
                    label: LocalizedStringKey("Thinking"),
                    isActive: isThinkingEnabled
                ) {
                    isThinkingEnabled.toggle()
                }

                // Web Search Toggle
                TogglePill(
                    icon: "globe",
                    label: LocalizedStringKey("Search"),
                    isActive: searchEnabled
                ) {
                    searchEnabled.toggle()
                }

                // MCP Tools Toggle
                TogglePill(
                    icon: "cpu",
                    label: LocalizedStringKey("MCP"),
                    isActive: mcpToolsEnabled
                ) {
                    mcpToolsEnabled.toggle()
                }

                // Context Level Cycle Toggle
                Button {
                    cycleContextLevel()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                        Text(LocalizedStringKey(currentContextLevel.displayName))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentContextLevel != .none ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                    )
                    .foregroundStyle(currentContextLevel != .none ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("Toggle Document Context Level"))

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

    private func cycleContextLevel() {
        switch currentContextLevel {
        case .none: contextLevelRaw = AIContextLevel.metadata.rawValue
        case .metadata: contextLevelRaw = AIContextLevel.full.rawValue
        case .full: contextLevelRaw = AIContextLevel.none.rawValue
        }
    }
}

struct TogglePill: View {
    let icon: String
    let label: LocalizedStringKey
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
