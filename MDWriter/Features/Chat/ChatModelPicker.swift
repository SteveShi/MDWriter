//
//  ChatModelPicker.swift
//  MDWriter
//

import SwiftUI

struct ChatModelPicker: View {
    @Bindable var llmService: LLMService
    @State private var isShowingPopover: Bool = false

    var body: some View {
        Button {
            isShowingPopover.toggle()
            Task {
                await llmService.fetchAvailableModels()
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(llmService.availableModels.isEmpty ? Color.red : Color.green)
                    .frame(width: 7, height: 7)

                Text(currentModelLabel)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(llmService.config.provider.displayName, systemImage: llmService.config.provider.iconName)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button {
                        Task { await llmService.fetchAvailableModels() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                if llmService.availableModels.isEmpty {
                    Text(LocalizedStringKey("No models found. Ensure local engine is running."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(llmService.availableModels) { model in
                                Button {
                                    llmService.config.selectedModel = model.id
                                    isShowingPopover = false
                                } label: {
                                    HStack {
                                        Text(model.id)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if llmService.config.selectedModel == model.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(llmService.config.selectedModel == model.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            .padding(12)
            .frame(width: 240)
        }
    }

    private var currentModelLabel: String {
        if llmService.config.selectedModel.isEmpty {
            return llmService.config.provider.displayName
        }
        return llmService.config.selectedModel
    }
}
