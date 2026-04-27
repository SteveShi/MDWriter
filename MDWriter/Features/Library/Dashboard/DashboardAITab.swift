//
//  DashboardAITab.swift
//  MDWriter
//

import SwiftUI

#if canImport(FoundationModels)
    import FoundationModels

    @available(macOS 26.0, *)
    struct AITab: View {
        @Bindable var note: Note
        var text: String

        @State private var aiService = AIService()
        @State private var hasSummary = false

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    SectionHeader(title: LocalizedStringKey("Apple Intelligence"), icon: nil)
                    Spacer()
                    Circle()
                        .fill(aiService.isAvailable ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                }

                if !aiService.isAvailable {
                    Text(LocalizedStringKey("AI Unavailable"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(LocalizedStringKey("AI Summary"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task {
                                    await aiService.summarize(text: text)
                                    hasSummary = true
                                }
                            } label: {
                                Image(
                                    systemName: aiService.isProcessing
                                        ? "progress.indicator" : "arrow.clockwise"
                                )
                                .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .disabled(
                                aiService.isProcessing
                                    || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if aiService.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else if hasSummary && !aiService.result.isEmpty {
                            Text(aiService.result)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary.opacity(0.8))
                                .lineSpacing(3)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(6)
                        } else {
                            Text(LocalizedStringKey("Click refresh to generate AI summary"))
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider().opacity(0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("Quick Actions"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                await aiService.suggestTags(for: text)
                                for tag in aiService.suggestedTags {
                                    if !note.tags.contains(tag) {
                                        note.tags.append(tag)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tag")
                                    .font(.system(size: 11))
                                Text(LocalizedStringKey("Auto Tags"))
                                    .font(.system(size: 12))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            aiService.isProcessing
                                || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            Task {
                                await aiService.generateTitle(for: text)
                                if !aiService.result.isEmpty {
                                    note.title = aiService.result
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "textformat")
                                    .font(.system(size: 11))
                                Text(LocalizedStringKey("Smart Title"))
                                    .font(.system(size: 12))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            aiService.isProcessing
                                || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
#endif
