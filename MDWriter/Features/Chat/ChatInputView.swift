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

                // Mention Context Menu
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
                    HStack(spacing: 3) {
                        Image(systemName: "at")
                            .font(.system(size: 10, weight: .bold))
                        Text(LocalizedStringKey("Mention"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("Mention Note, Folder, or Memos (@)"))

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

                // Vision OCR Button
                Button {
                    importAndRecognizeImage()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 10, weight: .bold))
                        Text(LocalizedStringKey("OCR"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("Extract text from image using on-device OCR"))

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
