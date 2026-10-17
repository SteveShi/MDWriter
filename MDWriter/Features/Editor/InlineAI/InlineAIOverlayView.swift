//
//  InlineAIOverlayView.swift
//  MDWriter
//
//  Main floating overlay coordinating Inline Command Bar, Diff Review, and Selection Toolbar.
//

import SwiftUI

struct InlineAIOverlayView: View {
    @ObservedObject var editorController: EditorController
    @ObservedObject var inlineController: InlineAIController
    var note: Note?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            // MARK: - 1. Selection Floating Capsule (when bar is hidden)
            if inlineController.state == .hidden && editorController.selectedRange.length > 5 {
                VStack {
                    Spacer()
                    SelectionFloatingBar(
                        editorController: editorController,
                        inlineController: inlineController,
                        note: note
                    )
                    .padding(.bottom, 72) // Just above the bottom markup bar
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                .zIndex(90)
            }

            // MARK: - 2. Active Inline Command / Diff Review Panel
            if inlineController.state != .hidden {
                // Dimming tap-out backdrop (optional subtle interaction)
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if inlineController.state != .generating {
                            inlineController.hide(controller: editorController)
                        }
                    }

                VStack {
                    // Position the panel in the upper-third of editor for optimal ergonomics
                    VStack(spacing: 0) {
                        switch inlineController.state {
                        case .input, .generating:
                            InlineAICommandBar(
                                inlineController: inlineController,
                                editorController: editorController,
                                note: note
                            )
                        case .reviewingDiff:
                            InlineAIDiffView(
                                originalText: inlineController.originalText,
                                modifiedText: inlineController.generatedText,
                                onAccept: {
                                    inlineController.accept(
                                        controller: editorController,
                                        note: note,
                                        modelContext: modelContext
                                    )
                                },
                                onReject: {
                                    inlineController.reject(controller: editorController)
                                },
                                onRetry: {
                                    inlineController.retry(
                                        note: note,
                                        controller: editorController,
                                        modelContext: modelContext
                                    )
                                }
                            )
                        case .hidden:
                            EmptyView()
                        }
                    }
                    .frame(width: 490)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 6)
                    .padding(.top, 64)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity).combined(with: .move(edge: .top)),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                    ))

                    Spacer()
                }
                .zIndex(150)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: inlineController.state)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: editorController.selectedRange.length > 5)
    }
}
