//
//  QuickEntryView.swift
//  MDWriter
//
//  Created by Steve Shi on 2026/10/18.
//

import AppKit
import SwiftData
import SwiftUI

/// 菜单栏全局速记浮窗卡片
struct QuickEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.name) private var folders: [Folder]

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedFolder: Folder? = nil
    @State private var tagInput: String = ""
    @State private var isSavedFeedback: Bool = false

    var onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶栏：速记标题与状态
            HStack {
                Label(LocalizedStringKey("Quick Entry"), systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if isSavedFeedback {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(LocalizedStringKey("Saved to Inbox"))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .transition(.opacity)
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("Close (Esc)"))
            }

            // 标题输入（可选，留空则自动提取正文首行）
            TextField(LocalizedStringKey("Title (Optional)"), text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)

            // Markdown 正文编辑区
            TextEditor(text: $content)
                .font(.system(size: 13, design: .default))
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 120, maxHeight: 220)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)
                .overlay(
                    Group {
                        if content.isEmpty {
                            VStack {
                                HStack {
                                    Text(LocalizedStringKey("Write a quick thought, memo or markdown note..."))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 10)
                                        .padding(.top, 10)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .allowsHitTesting(false)
                        }
                    }
                )

            // 文件夹选择与标签
            HStack(spacing: 8) {
                Menu {
                    Button(LocalizedStringKey("Inbox (Default)")) {
                        selectedFolder = nil
                    }
                    Divider()
                    ForEach(folders) { folder in
                        Button(folder.name) {
                            selectedFolder = folder
                        }
                    }
                } label: {
                    Label(
                        selectedFolder?.name ?? String(localized: "Inbox"),
                        systemImage: selectedFolder == nil ? "tray" : "folder"
                    )
                    .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                // 快捷键提示
                Text("⌘ ⏎")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .quaternaryLabelColor))
                    .cornerRadius(4)

                // 保存按钮
                Button {
                    saveQuickEntry()
                } label: {
                    Label(LocalizedStringKey("Save Note"), systemImage: "arrow.down.circle.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(.ultraThinMaterial)
    }

    private func saveQuickEntry() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        var noteTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if noteTitle.isEmpty {
            // 从第一行提取标题
            let lines = trimmedContent.components(separatedBy: .newlines)
            if let first = lines.first {
                let cleaned = first.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).trimmingCharacters(in: .whitespaces)
                noteTitle = cleaned.isEmpty ? String(localized: "Quick Note") : cleaned
            } else {
                noteTitle = String(localized: "Quick Note")
            }
        }

        let newNote = Note(title: noteTitle, content: trimmedContent, folder: selectedFolder)
        modelContext.insert(newNote)
        try? modelContext.save()

        withAnimation {
            isSavedFeedback = true
        }

        // 延迟收起浮窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            title = ""
            content = ""
            isSavedFeedback = false
            onDismiss()
        }
    }
}
