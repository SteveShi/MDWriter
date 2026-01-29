//
//  UlyssesBottomToolbar.swift
//  MDWriter
//
//  Ulysses 风格的底部快捷工具栏
//

import MDEditor
import SwiftUI

struct UlyssesBottomToolbar: View {
    @ObservedObject var controller: EditorController
    @State private var showMoreOptions = false

    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Divider()
                .opacity(0.3)

            // 工具栏内容
            HStack(spacing: 0) {
                Spacer()

                HStack(spacing: 24) {
                    // 副标题
                    ToolbarTextButton(label: "### \(String(localized: "Subheading"))") {
                        controller.insertMarkup("### ")
                    }

                    // 列表
                    ToolbarTextButton(label: "- \(String(localized: "List"))") {
                        controller.insertMarkup("- ")
                    }

                    // 引用块
                    ToolbarTextButton(label: "> \(String(localized: "Blockquote"))") {
                        controller.insertMarkup("> ")
                    }

                    // 更多选项
                    Button {
                        showMoreOptions.toggle()
                    } label: {
                        Text("···")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMoreOptions, arrowEdge: .bottom) {
                        MoreOptionsPopover(controller: controller)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
    }
}

// MARK: - Toolbar Text Button

private struct ToolbarTextButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - More Options Popover

private struct MoreOptionsPopover: View {
    @ObservedObject var controller: EditorController
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PopoverSection(title: "Headings") {
                PopoverButton(label: "# \(String(localized: "Major Heading"))", shortcut: "⌘\\") {
                    controller.insertMarkup("# ")
                    dismiss()
                }
                PopoverButton(label: "## \(String(localized: "Heading"))", shortcut: nil) {
                    controller.insertMarkup("## ")
                    dismiss()
                }
                PopoverButton(label: "### \(String(localized: "Subheading"))", shortcut: nil) {
                    controller.insertMarkup("### ")
                    dismiss()
                }
            }

            Divider()

            PopoverSection(title: "Format") {
                PopoverButton(label: String(localized: "Bold"), shortcut: "⌘B") {
                    controller.toggleBold()
                    dismiss()
                }
                PopoverButton(label: String(localized: "Italic"), shortcut: "⌘I") {
                    controller.toggleItalic()
                    dismiss()
                }
                PopoverButton(label: String(localized: "Strikethrough"), shortcut: "⌘U") {
                    controller.toggleStrikethrough()
                    dismiss()
                }
                PopoverButton(label: String(localized: "Inline Code"), shortcut: "⌘`") {
                    controller.toggleInlineCode()
                    dismiss()
                }
            }

            Divider()

            PopoverSection(title: "Structure") {
                PopoverButton(label: "- \(String(localized: "Bulleted List"))", shortcut: nil) {
                    controller.insertMarkup("- ")
                    dismiss()
                }
                PopoverButton(label: "1. \(String(localized: "Numbered List"))", shortcut: nil) {
                    controller.insertMarkup("1. ")
                    dismiss()
                }
                PopoverButton(label: "- [ ] \(String(localized: "Task List"))", shortcut: nil) {
                    controller.insertMarkup("- [ ] ")
                    dismiss()
                }
                PopoverButton(label: "> \(String(localized: "Blockquote"))", shortcut: nil) {
                    controller.insertMarkup("> ")
                    dismiss()
                }
                PopoverButton(label: "``` \(String(localized: "Code Block"))", shortcut: nil) {
                    controller.insertMarkup("```\n\n```")
                    dismiss()
                }
            }

            Divider()

            PopoverSection(title: "Insert") {
                PopoverButton(label: String(localized: "Link"), shortcut: "⌘K") {
                    controller.insertLinkMarkup()
                    dismiss()
                }
                PopoverButton(label: String(localized: "Image"), shortcut: nil) {
                    controller.insertImageMarkup()
                    dismiss()
                }
                PopoverButton(label: String(localized: "Horizontal Rule"), shortcut: nil) {
                    controller.insertMarkup("\n---\n")
                    dismiss()
                }
            }
        }
        .padding(12)
        .frame(width: 200)
    }
}

// MARK: - Popover Section

private struct PopoverSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            content
        }
    }
}

// MARK: - Popover Button

private struct PopoverButton: View {
    let label: String
    let shortcut: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UlyssesBottomToolbar(controller: EditorController())
        .frame(width: 600)
}
