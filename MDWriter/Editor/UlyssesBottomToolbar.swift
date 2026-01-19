//
//  UlyssesBottomToolbar.swift
//  MDWriter
//
//  Ulysses 风格的底部快捷工具栏
//

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
                    ToolbarTextButton(label: "### 副标题") {
                        controller.insertMarkup("### ")
                    }

                    // 列表
                    ToolbarTextButton(label: "- 列表") {
                        controller.insertMarkup("- ")
                    }

                    // 引用块
                    ToolbarTextButton(label: "> 引用块") {
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
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(Color.platformBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
            PopoverSection(title: "标题") {
                PopoverButton(label: "# 大标题", shortcut: "⌘\\") {
                    controller.insertMarkup("# ")
                    dismiss()
                }
                PopoverButton(label: "## 标题", shortcut: nil) {
                    controller.insertMarkup("## ")
                    dismiss()
                }
                PopoverButton(label: "### 副标题", shortcut: nil) {
                    controller.insertMarkup("### ")
                    dismiss()
                }
            }

            Divider()

            PopoverSection(title: "格式") {
                PopoverButton(label: "粗体", shortcut: "⌘B") {
                    controller.toggleBold()
                    dismiss()
                }
                PopoverButton(label: "斜体", shortcut: "⌘I") {
                    controller.toggleItalic()
                    dismiss()
                }
                PopoverButton(label: "删除线", shortcut: "⌘U") {
                    controller.toggleStrikethrough()
                    dismiss()
                }
                PopoverButton(label: "行内代码", shortcut: "⌘`") {
                    controller.toggleInlineCode()
                    dismiss()
                }
            }

            Divider()

            PopoverSection(title: "结构") {
                PopoverButton(label: "- 无序列表", shortcut: nil) {
                    controller.insertMarkup("- ")
                    dismiss()
                }
                PopoverButton(label: "1. 有序列表", shortcut: nil) {
                    controller.insertMarkup("1. ")
                    dismiss()
                }
                PopoverButton(label: "- [ ] 任务列表", shortcut: nil) {
                    controller.insertMarkup("- [ ] ")
                    dismiss()
                }
                PopoverButton(label: "> 引用块", shortcut: nil) {
                    controller.insertMarkup("> ")
                    dismiss()
                }
                PopoverButton(label: "``` 代码块", shortcut: nil) {
                    controller.insertMarkup("```\n\n```")
                    dismiss()
                }
            }

            Divider()

            PopoverSection(title: "插入") {
                PopoverButton(label: "链接", shortcut: "⌘K") {
                    controller.insertLinkMarkup()
                    dismiss()
                }
                PopoverButton(label: "图片", shortcut: nil) {
                    controller.insertImageMarkup()
                    dismiss()
                }
                PopoverButton(label: "分隔线", shortcut: nil) {
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
