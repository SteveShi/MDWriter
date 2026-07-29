//
//  ChatPanelView.swift
//  MDWriter
//

import SwiftData
import SwiftUI

struct ChatPanelView: View {
    @ObservedObject var controller: EditorController
    var note: Note?
    @Binding var isPresented: Bool

    @State private var llmService = LLMService()
    @State private var inputText: String = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            // Chat Messages List
            if let note = note {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            let messages = note.chatMessages.sorted(by: { $0.timestamp < $1.timestamp })
                            ForEach(messages) { msg in
                                ChatMessageView(message: msg, controller: controller)
                                    .id(msg.id)
                            }

                            if llmService.isProcessing && !llmService.currentStreamingText.isEmpty {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text(llmService.config.selectedModel)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }

                                        Text(llmService.currentStreamingText)
                                            .font(.system(size: 13))
                                            .lineSpacing(3)
                                    }
                                    .padding(12)
                                    .background(Color.secondary.opacity(0.06))
                                    .cornerRadius(12)

                                    Spacer(minLength: 40)
                                }
                                .padding(.horizontal, 12)
                                .id("streaming_bottom")
                            }

                            if let error = llmService.errorMessage {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.08))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: note.chatMessages.count) { _, _ in
                        if let last = note.chatMessages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(LocalizedStringKey("Select a note to start AI conversation"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            Divider()

            // Input View
            ChatInputView(
                text: $inputText,
                isProcessing: llmService.isProcessing,
                onSend: {
                    let prompt = inputText
                    inputText = ""
                    Task {
                        await llmService.sendMessage(
                            userText: prompt,
                            note: note,
                            editorController: controller,
                            modelContext: modelContext
                        )
                    }
                },
                onCancel: {
                    llmService.cancel()
                },
                controller: controller,
                note: note
            )
        }
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 420)
        .background(.ultraThinMaterial)
        .onAppear {
            Task {
                await llmService.fetchAvailableModels()
                await MCPClientManager.shared.reloadAndConnectAll()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)

                Text(LocalizedStringKey("AI Chat"))
                    .font(.system(size: 14, weight: .bold))
            }

            Spacer()

            ChatModelPicker(llmService: llmService)

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
