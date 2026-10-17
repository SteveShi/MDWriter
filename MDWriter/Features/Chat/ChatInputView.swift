//
//  ChatInputView.swift
//  MDWriter
//

import SwiftData
import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    var isProcessing: Bool
    var onSend: () -> Void
    var onCancel: () -> Void
    @ObservedObject var controller: EditorController
    var note: Note?

    @Query(filter: #Predicate<Note> { !$0.isTrashed }, sort: \Note.modifiedAt, order: .reverse)
    private var recentNotes: [Note]

    @Query(sort: \Folder.name)
    private var folders: [Folder]

    @AppStorage("aiThinkingEnabled") private var isThinkingEnabled: Bool = false
    @AppStorage("searchEnabled") private var searchEnabled: Bool = true
    @AppStorage("mcpToolsEnabled") private var mcpToolsEnabled: Bool = true
    @AppStorage("aiContextLevel") private var contextLevelRaw: String = AIContextLevel.metadata.rawValue

    private var currentContextLevel: AIContextLevel {
        AIContextLevel(rawValue: contextLevelRaw) ?? .metadata
    }

    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Quick Control Toggles Bar (Horizontal Scrollable Capsule Pills)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // 1. Thinking Toggle (Purple semantic)
                    TogglePill(
                        icon: "brain",
                        label: LocalizedStringKey("Thinking"),
                        isActive: isThinkingEnabled,
                        activeColor: .purple
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            isThinkingEnabled.toggle()
                        }
                    }
                    .help(LocalizedStringKey("Toggle Extended Thinking Reasoning"))

                    // 2. Web Search Toggle (Blue semantic)
                    TogglePill(
                        icon: "globe",
                        label: LocalizedStringKey("Search"),
                        isActive: searchEnabled,
                        activeColor: .blue
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            searchEnabled.toggle()
                        }
                    }
                    .help(LocalizedStringKey("Toggle Web Search Grounding"))

                    // 3. MCP Tools Toggle (Orange semantic)
                    TogglePill(
                        icon: "cpu",
                        label: LocalizedStringKey("MCP"),
                        isActive: mcpToolsEnabled,
                        activeColor: .orange
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            mcpToolsEnabled.toggle()
                        }
                    }
                    .help(LocalizedStringKey("Toggle Model Context Protocol (MCP) Tools"))

                    // 4. Mention Context Menu
                    Menu {
                        if !recentNotes.isEmpty {
                            Menu(LocalizedStringKey("Insert Note Reference")) {
                                ForEach(recentNotes.prefix(8)) { n in
                                    Button {
                                        insertMention("@Note: \"\(n.title)\" ")
                                    } label: {
                                        Label(n.title, systemImage: "doc.text")
                                    }
                                }
                            }
                        }

                        if !folders.isEmpty {
                            Menu(LocalizedStringKey("Insert Folder Reference")) {
                                ForEach(folders) { f in
                                    Button {
                                        insertMention("@Folder: \"\(f.name)\" ")
                                    } label: {
                                        Label(f.name, systemImage: "folder")
                                    }
                                }
                            }
                        }

                        if let note = note, !note.memos.isEmpty {
                            Button {
                                insertMention("@Memo ")
                            } label: {
                                Label(LocalizedStringKey("Insert Active Memos (@Memo)"), systemImage: "note.text")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "at")
                                .font(.system(size: 10, weight: .semibold))
                            Text(LocalizedStringKey("Mention"))
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .opacity(0.6)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .foregroundStyle(Color.secondary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("Mention Note, Folder, or Memos (@)"))

                    // 5. Context Level Cycle Toggle
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            cycleContextLevel()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: contextLevelIcon)
                                .font(.system(size: 10, weight: currentContextLevel != .none ? .semibold : .regular))
                            Text(LocalizedStringKey(currentContextLevel.displayName))
                                .font(.system(size: 11, weight: currentContextLevel != .none ? .semibold : .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(
                            Capsule(style: .continuous)
                                .fill(currentContextLevel != .none ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(currentContextLevel != .none ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .foregroundStyle(currentContextLevel != .none ? Color.accentColor : Color.secondary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("Toggle Document Context Level"))

                    // 6. Vision OCR Button
                    Button {
                        importAndRecognizeImage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 10, weight: .medium))
                            Text(LocalizedStringKey("OCR"))
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .foregroundStyle(Color.secondary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(LocalizedStringKey("Extract text from image using on-device OCR"))
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
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

    private var contextLevelIcon: String {
        switch currentContextLevel {
        case .full: return "doc.text.fill"
        case .metadata: return "doc.text"
        case .none: return "doc.badge.slash"
        }
    }

    private func cycleContextLevel() {
        switch currentContextLevel {
        case .none: contextLevelRaw = AIContextLevel.metadata.rawValue
        case .metadata: contextLevelRaw = AIContextLevel.full.rawValue
        case .full: contextLevelRaw = AIContextLevel.none.rawValue
        }
    }

    private func insertMention(_ token: String) {
        if text.isEmpty || text.hasSuffix(" ") || text.hasSuffix("\n") {
            text += token
        } else {
            text += " " + token
        }
    }

    private func importAndRecognizeImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        panel.prompt = String(localized: "Select Image")

        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                do {
                    let result = try await VisionOCRService.shared.recognizeText(fromFileURL: url)
                    if !result.recognizedText.isEmpty {
                        if !text.isEmpty {
                            text += "\n\n"
                        }
                        text += "[OCR Extracted Text]:\n" + result.recognizedText
                    }
                } catch {
                    print("OCR Error: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct TogglePill: View {
    let icon: String
    let label: LocalizedStringKey
    let isActive: Bool
    var activeColor: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? activeColor.opacity(0.14) : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isActive ? activeColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .foregroundStyle(isActive ? activeColor : Color.secondary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
