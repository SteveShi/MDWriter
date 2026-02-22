//
//  AIAssistantView.swift
//  MDWriter
//
//  AI Assistant popover panel with all AI writing features.
//

import SwiftUI

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
struct AIAssistantView: View {
    @ObservedObject var controller: EditorController
    var note: Note?

    @State private var aiService = AIService()
    @State private var selectedAction: AIAction?
    @State private var inputText: String = ""

    @AppStorage("aiEnabled") private var aiEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if !aiService.isAvailable {
                unavailableView
            } else if !aiEnabled {
                disabledView
            } else if let action = selectedAction {
                // Result view
                resultView(for: action)
            } else {
                // Action grid
                actionGrid
            }
        }
        .frame(width: 360, height: 420)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if selectedAction != nil {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedAction = nil
                        aiService.reset()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "apple.intelligence")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.multicolor)
                Text(LocalizedStringKey("AI Assistant"))
                    .font(.system(size: 14, weight: .semibold))
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(aiService.isAvailable ? Color.green : Color.red)
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Action Grid

    private var actionGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(AIAction.allCases) { action in
                    AIActionCard(action: action) {
                        guard let note = note else { return }
                        inputText = controller.proxy.getSelectedText() ?? note.content
                        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        withAnimation(.spring(response: 0.3)) {
                            selectedAction = action
                        }
                        executeAction(action)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Result View

    @ViewBuilder
    private func resultView(for action: AIAction) -> some View {
        VStack(spacing: 0) {
            // Action info bar
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(action.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()

                if aiService.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.06))

            // Result content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let error = aiService.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(8)
                    }

                    if !aiService.result.isEmpty {
                        Text(aiService.result)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Tags display (for suggestTags)
                    if !aiService.suggestedTags.isEmpty {
                        tagResultView
                    }

                    // Corrections list (for proofread)
                    if !aiService.corrections.isEmpty {
                        correctionsView
                    }
                }
                .padding(16)
            }

            Divider()

            // Action buttons
            if !aiService.isProcessing && !aiService.result.isEmpty {
                resultActions(for: action)
            }
        }
    }

    private var tagResultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("Suggested Tags"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            FlowLayout(items: aiService.suggestedTags) { tag in
                Text(tag)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(12)
            }
        }
    }

    private var correctionsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("Corrections"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(aiService.corrections, id: \.self) { correction in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                    Text(correction)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func resultActions(for action: AIAction) -> some View {
        HStack(spacing: 12) {
            // Copy
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(aiService.result, forType: .string)
            } label: {
                Label(LocalizedStringKey("Copy"), systemImage: "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            // Apply tags to note
            if action == .suggestTags, let note = note {
                Button {
                    for tag in aiService.suggestedTags {
                        if !note.tags.contains(tag) {
                            note.tags.append(tag)
                        }
                    }
                } label: {
                    Label(LocalizedStringKey("Apply Tags"), systemImage: "tag")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // Replace selected text
            if action == .polish || action == .translate || action == .proofread {
                Button {
                    controller.proxy.insert(aiService.result)
                } label: {
                    Label(LocalizedStringKey("Replace Selection"), systemImage: "arrow.turn.down.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // Insert at cursor
            if action == .summarize || action == .generateTitle {
                Button {
                    controller.proxy.insert(aiService.result)
                } label: {
                    Label(LocalizedStringKey("Insert Result"), systemImage: "text.insert")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Unavailable / Disabled

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "apple.intelligence")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(LocalizedStringKey("AI Unavailable"))
                .font(.system(size: 15, weight: .semibold))
            Text(LocalizedStringKey("Requires macOS 26 and Apple Silicon"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    private var disabledView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "apple.intelligence")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(LocalizedStringKey("AI Features Disabled"))
                .font(.system(size: 15, weight: .semibold))
            Text(LocalizedStringKey("Enable AI features in Settings > AI"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Execute

    private func executeAction(_ action: AIAction) {
        Task {
            switch action {
            case .polish:
                await aiService.polish(text: inputText)
            case .summarize:
                await aiService.summarize(text: inputText)
            case .translate:
                await aiService.translate(text: inputText)
            case .generateTitle:
                await aiService.generateTitle(for: inputText)
            case .proofread:
                await aiService.proofread(text: inputText)
            case .suggestTags:
                await aiService.suggestTags(for: inputText)
            }
        }
    }
}

// MARK: - Action Card

@available(macOS 26.0, *)
struct AIActionCard: View {
    let action: AIAction
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: action.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 28)

                Text(action.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Text(action.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#endif
