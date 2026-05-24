//
//  UlyssesMarkupBar.swift
//  MDWriter
//
//  Ulysses 风格的上下文敏感 Markup Bar
//  - 与编辑器背景融为一体，只有分隔线
//  - 根据选中内容智能切换模式
//  - MD符号用浅灰色，文字用稍亮颜色
//

import Combine
import MDEditorKit
import SwiftUI

// MARK: - 选区上下文类型

/// Ulysses 风格的上下文枚举：根据光标/选区所在位置切换按钮组。
enum SelectionContext: Equatable, Hashable {
    /// 无选区，空段落。关联值是"基于上一行 heading 推荐"的下一级标题级别（1…3）。
    /// - 纯空白文档或上一行不是 heading → 1（默认大标题）
    /// - 上一行是 `# H1` → 2
    /// - 上一行是 `## H2` → 3
    /// - 上一行是 `### H3` 及更深 → 1（不再继续下沉）
    case empty(suggestedHeadingLevel: Int)
    /// 无选区，光标位于标题行（# / ## / ###）。关联值是当前行的 heading 级别（1…6）。
    case headingLine(level: Int)
    /// 无选区，光标位于列表行（- / 1. / - [ ]）
    case listLine
    /// 无选区，光标位于引用行（>）
    case quoteLine
    /// 无选区，光标位于围栏代码块内
    case codeBlock
    /// 选中行内文本
    case inlineText
    /// 选中整行或跨行
    case fullLines
}

// MARK: - Markup Bar View Model

class MarkupBarViewModel: ObservableObject {
    @Published var context: SelectionContext = .empty(suggestedHeadingLevel: 1)
    @Published var selectedText: String = ""

    /// 更新选区上下文
    func updateContext(selectedRange: NSRange, fullText: String) {
        let nsText = fullText as NSString
        // 防御性边界检查，避免 MDEditor 偶发越界
        guard selectedRange.location <= nsText.length,
            NSMaxRange(selectedRange) <= nsText.length
        else {
            return
        }

        selectedText =
            selectedRange.length > 0 ? nsText.substring(with: selectedRange) : ""
        let newContext = analyze(range: selectedRange, in: nsText)

        if context != newContext {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                context = newContext
            }
        }
    }

    private func analyze(range: NSRange, in text: NSString) -> SelectionContext {
        // 有选区：判定行内 vs 跨行
        if range.length > 0 {
            let selected = text.substring(with: range)
            if selected.contains("\n") {
                return .fullLines
            }
            let lineRange = text.lineRange(for: range)
            let isFullLine =
                range.location == lineRange.location
                && (NSMaxRange(range) >= NSMaxRange(lineRange) - 1
                    || NSMaxRange(range) == NSMaxRange(lineRange))
            return isFullLine ? .fullLines : .inlineText
        }

        // 无选区：根据光标所在行的开头标记决定上下文
        if isInsideFencedCodeBlock(location: range.location, in: text) {
            return .codeBlock
        }

        let lineRange = text.lineRange(for: NSRange(location: range.location, length: 0))
        let line = text.substring(with: lineRange)
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t\n\r"))

        if let level = Self.headingLevel(of: trimmed) {
            return .headingLine(level: level)
        }
        if trimmed.hasPrefix(">") {
            return .quoteLine
        }
        if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]")
            || trimmed.hasPrefix("- [X]") || trimmed.hasPrefix("- ")
            || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")
            || isOrderedListPrefix(trimmed)
        {
            return .listLine
        }

        // 空行（或不带任何 block 前缀的普通段落）：基于上一行 heading 级别给出推荐。
        return .empty(suggestedHeadingLevel: suggestedHeadingLevel(
            for: lineRange, in: text))
    }

    /// 解析行首 `#…#` 后跟空格的 heading 级别（1…6）；非 heading 返回 nil。
    private static func headingLevel(of line: String) -> Int? {
        var count = 0
        for ch in line {
            if ch == "#" {
                count += 1
                if count > 6 { return nil }
            } else if ch == " " || ch == "\t" {
                return count >= 1 ? count : nil
            } else {
                return nil
            }
        }
        return nil
    }

    /// 当光标在空行/普通段落时，根据上一行 heading 级别推荐应当出现的下一级标题。
    /// - 上一行是 H1 → 2；H2 → 3；其它（含 H3+/列表/正文/无上一行）→ 1。
    private func suggestedHeadingLevel(for lineRange: NSRange, in text: NSString) -> Int {
        var cursor = lineRange.location
        // 向上跨过空白行
        while cursor > 0 {
            // 拿到前一行
            let prevLineRange = text.lineRange(
                for: NSRange(location: cursor - 1, length: 0))
            let prevLine = text.substring(with: prevLineRange)
                .trimmingCharacters(in: .init(charactersIn: " \t\n\r"))
            if prevLine.isEmpty {
                cursor = prevLineRange.location
                continue
            }
            if let level = Self.headingLevel(of: prevLine) {
                switch level {
                case 1: return 2
                case 2: return 3
                default: return 1
                }
            }
            return 1
        }
        return 1
    }

    /// 判断 "1. " / "12. " 等有序列表行
    private func isOrderedListPrefix(_ s: String) -> Bool {
        var idx = s.startIndex
        var sawDigit = false
        while idx < s.endIndex, s[idx].isNumber {
            sawDigit = true
            idx = s.index(after: idx)
        }
        guard sawDigit, idx < s.endIndex, s[idx] == "." else { return false }
        let afterDot = s.index(after: idx)
        return afterDot < s.endIndex && s[afterDot] == " "
    }

    /// 判断光标是否位于围栏代码块（``` … ```）内：统计光标前 ``` 出现次数为奇数。
    private func isInsideFencedCodeBlock(location: Int, in text: NSString) -> Bool {
        guard location > 0 else { return false }
        let prefix = text.substring(with: NSRange(location: 0, length: location)) as NSString
        var count = 0
        var searchRange = NSRange(location: 0, length: prefix.length)
        while searchRange.location < prefix.length {
            let found = prefix.range(of: "```", options: [], range: searchRange)
            if found.location == NSNotFound { break }
            count += 1
            let next = NSMaxRange(found)
            searchRange = NSRange(location: next, length: prefix.length - next)
        }
        return count % 2 == 1
    }
}

// MARK: - 主视图

struct UlyssesMarkupBar: View {
    @ObservedObject var controller: EditorController
    @StateObject private var viewModel = MarkupBarViewModel()
    @State private var showMorePopover = false

    var body: some View {
        VStack(spacing: 0) {
            // 分隔线 - 唯一的视觉区分
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 40)  // 左右留出边距，不贯穿全屏

            HStack(spacing: 0) {
                Spacer()

                // 主要内容：始终根据上下文渲染按钮组
                HStack(spacing: 28) {
                    contextualButtons
                        .id(viewModel.context)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))

                    // 更多选项
                    moreButton
                }

                Spacer()
            }
            .padding(.vertical, 10)
            // 透明背景，与编辑器融为一体
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.context)
        // 跟随 EditorController 直接订阅 MDEditor 1.7.1+ 的实时选区/文本，
        // 不再依赖 NotificationCenter，纯光标移动也能驱动上下文切换。
        .onReceive(controller.$selectedRange) { range in
            viewModel.updateContext(selectedRange: range, fullText: controller.fullText)
        }
        .onReceive(controller.$fullText) { text in
            viewModel.updateContext(selectedRange: controller.selectedRange, fullText: text)
        }
        .onAppear {
            viewModel.updateContext(
                selectedRange: controller.selectedRange,
                fullText: controller.fullText
            )
        }
    }

    // MARK: - 上下文按钮组

    @ViewBuilder
    private var contextualButtons: some View {
        switch viewModel.context {
        case .empty(let suggestedLevel):
            // 空段落：根据上一行 heading 推荐的下一级标题作为首要按钮。
            // suggestedLevel=1 → 主推 H1；2 → 主推 H2；3 → 主推 H3。
            HStack(spacing: 28) {
                emptyHeadingButton(for: suggestedLevel)
                MarkupButton(symbol: "-", label: LocalizedStringKey("List")) {
                    controller.applyBlockPrefix("- ")
                }
                MarkupButton(symbol: ">", label: LocalizedStringKey("Blockquote")) {
                    controller.applyBlockPrefix("> ")
                }
            }
        case .headingLine:
            // 光标在标题行：直接切换标题级别（替换前缀，而不是追加）
            HStack(spacing: 28) {
                MarkupButton(symbol: "#", label: LocalizedStringKey("Major Heading")) {
                    controller.applyBlockPrefix("# ")
                }
                MarkupButton(symbol: "##", label: LocalizedStringKey("Heading")) {
                    controller.applyBlockPrefix("## ")
                }
                MarkupButton(symbol: "###", label: LocalizedStringKey("Subheading")) {
                    controller.applyBlockPrefix("### ")
                }
            }
        case .listLine:
            // 光标在列表行：列表类型快捷切换（替换前缀）
            HStack(spacing: 28) {
                MarkupButton(symbol: "-", label: LocalizedStringKey("Bulleted List")) {
                    controller.applyBlockPrefix("- ")
                }
                MarkupButton(symbol: "1.", label: LocalizedStringKey("Numbered List")) {
                    controller.applyBlockPrefix("1. ")
                }
                MarkupButton(symbol: "[ ]", label: LocalizedStringKey("Task List")) {
                    controller.applyBlockPrefix("- [ ] ")
                }
            }
        case .quoteLine:
            // 光标在引用行：常见的引用内补充（替换前缀）
            HStack(spacing: 28) {
                MarkupButton(symbol: ">", label: LocalizedStringKey("Blockquote")) {
                    controller.applyBlockPrefix("> ")
                }
                MarkupButton(symbol: "-", label: LocalizedStringKey("List")) {
                    controller.applyBlockPrefix("- ")
                }
                MarkupButton(symbol: "##", label: LocalizedStringKey("Small Heading")) {
                    controller.applyBlockPrefix("## ")
                }
            }
        case .codeBlock:
            // 光标在围栏代码块内：仅提供与代码相关的格式
            HStack(spacing: 28) {
                MarkupButton(symbol: "`", label: LocalizedStringKey("Inline Code")) {
                    controller.toggleInlineCode()
                }
                MarkupButton(symbol: "```", label: LocalizedStringKey("Code Block")) {
                    controller.insertMarkup("```\n\n```")
                }
                MarkupButton(symbol: "---", label: LocalizedStringKey("Horizontal Rule")) {
                    controller.insertMarkup("\n---\n")
                }
            }
        case .inlineText:
            HStack(spacing: 28) {
                MarkupButton(symbol: "**", label: LocalizedStringKey("Bold")) {
                    controller.toggleBold()
                }
                MarkupButton(symbol: "*", label: LocalizedStringKey("Italic")) {
                    controller.toggleItalic()
                }
                MarkupButton(symbol: "[", label: LocalizedStringKey("Link")) {
                    controller.insertLinkMarkup()
                }
            }
        case .fullLines:
            HStack(spacing: 28) {
                MarkupButton(symbol: "##", label: LocalizedStringKey("Small Heading")) {
                    controller.applyBlockPrefix("## ")
                }
                MarkupButton(symbol: "-", label: LocalizedStringKey("List")) {
                    controller.applyBlockPrefix("- ")
                }
                MarkupButton(symbol: ">", label: LocalizedStringKey("Blockquote")) {
                    controller.applyBlockPrefix("> ")
                }
            }
        }
    }

    /// 空段落首要标题按钮：根据上一行 heading 推荐当前应该呈现的级别。
    @ViewBuilder
    private func emptyHeadingButton(for level: Int) -> some View {
        switch level {
        case 1:
            MarkupButton(symbol: "#", label: LocalizedStringKey("Major Heading")) {
                controller.applyBlockPrefix("# ")
            }
        case 2:
            MarkupButton(symbol: "##", label: LocalizedStringKey("Heading")) {
                controller.applyBlockPrefix("## ")
            }
        default:
            MarkupButton(symbol: "###", label: LocalizedStringKey("Subheading")) {
                controller.applyBlockPrefix("### ")
            }
        }
    }

    // MARK: - 更多按钮

    private var moreButton: some View {
        Button {
            showMorePopover.toggle()
        } label: {
            Text("···")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showMorePopover, arrowEdge: .top) {
            MarkupPopover(controller: controller)
        }
    }

}

// MARK: - Markup 按钮（仿 Ulysses 样式）

struct MarkupButton: View {
    let symbol: String
    let label: LocalizedStringKey
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                // MD 符号 - 浅灰色
                Text(symbol)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.45))

                // 文字标签 - 稍亮
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(isHovered ? .secondary.opacity(0.8) : .secondary.opacity(0.6))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 更多选项弹出框

struct MarkupPopover: View {
    @ObservedObject var controller: EditorController
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverSection(title: LocalizedStringKey("Headings")) {
                PopoverItem(
                    symbol: "#", label: LocalizedStringKey("Major Heading"), shortcut: "⌘\\"
                ) {
                    controller.insertMarkup("# ")
                    dismiss()
                }
                PopoverItem(symbol: "##", label: LocalizedStringKey("Heading")) {
                    controller.insertMarkup("## ")
                    dismiss()
                }
                PopoverItem(symbol: "###", label: LocalizedStringKey("Subheading")) {
                    controller.insertMarkup("### ")
                    dismiss()
                }
            }

            Divider().padding(.horizontal, 10).padding(.vertical, 4)

            PopoverSection(title: LocalizedStringKey("Formatting")) {
                PopoverItem(symbol: "**", label: LocalizedStringKey("Bold"), shortcut: "⌘B") {
                    controller.toggleBold()
                    dismiss()
                }
                PopoverItem(symbol: "*", label: LocalizedStringKey("Italic"), shortcut: "⌘I") {
                    controller.toggleItalic()
                    dismiss()
                }
                PopoverItem(
                    symbol: "~~", label: LocalizedStringKey("Strikethrough"), shortcut: "⌘U"
                ) {
                    controller.toggleStrikethrough()
                    dismiss()
                }
                PopoverItem(symbol: "`", label: LocalizedStringKey("Code"), shortcut: "⌘`") {
                    controller.toggleInlineCode()
                    dismiss()
                }
            }

            Divider().padding(.horizontal, 10).padding(.vertical, 4)

            PopoverSection(title: LocalizedStringKey("Structure")) {
                PopoverItem(symbol: "-", label: LocalizedStringKey("Unordered List")) {
                    controller.insertMarkup("- ")
                    dismiss()
                }
                PopoverItem(symbol: "1.", label: LocalizedStringKey("Ordered List")) {
                    controller.insertMarkup("1. ")
                    dismiss()
                }
                PopoverItem(symbol: "[ ]", label: LocalizedStringKey("Task List")) {
                    controller.insertMarkup("- [ ] ")
                    dismiss()
                }
                PopoverItem(symbol: ">", label: LocalizedStringKey("Blockquote")) {
                    controller.insertMarkup("> ")
                    dismiss()
                }
                PopoverItem(symbol: "```", label: LocalizedStringKey("Code Block")) {
                    controller.insertMarkup("```\n\n```")
                    dismiss()
                }
            }

            Divider().padding(.horizontal, 10).padding(.vertical, 4)

            PopoverSection(title: LocalizedStringKey("Insert")) {
                PopoverItem(symbol: "[]", label: LocalizedStringKey("Link"), shortcut: "⌘K") {
                    controller.insertLinkMarkup()
                    dismiss()
                }
                PopoverItem(symbol: "![", label: LocalizedStringKey("Image")) {
                    controller.insertImageMarkup()
                    dismiss()
                }
                PopoverItem(symbol: "---", label: LocalizedStringKey("Separator")) {
                    controller.insertMarkup("\n---\n")
                    dismiss()
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 200)
    }
}

// MARK: - Popover 组件

private struct PopoverSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 2)

            content
        }
    }
}

private struct PopoverItem: View {
    let symbol: String
    let label: LocalizedStringKey
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // 符号
                Text(symbol)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 24, alignment: .leading)

                // 标签
                Text(label)
                    .font(.system(size: 12))

                Spacer()

                // 快捷键
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.08)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        UlyssesMarkupBar(controller: EditorController())
    }
    .frame(width: 600, height: 400)
}
