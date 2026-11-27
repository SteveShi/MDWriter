//
//  EditorMarkupBar.swift
//  MDWriter
//
//  上下文敏感的底部停靠快捷符号栏与可搜索命令面板：
//  - 由 MDEditorKit 的轻量 EditorCursorContext 驱动（零全文重构 + 40ms 防抖）
//  - 快捷按钮与「···」命令面板共用统一的 EditorActionItem 注册表
//  - 「···」面板支持按当前作用域动态排序、实时搜索过滤、匹配高亮、全键盘导航与主/次动作分层折叠
//  - 顶置细线对齐正文栏宽，搜索栏/内联 AI 弹出时自动隐藏，空白区拦截误触与光标抖动
//

import AppKit
import Combine
import MDEditorKit
import SwiftUI

// MARK: - 统一动作模型

enum EditorActionCategory: String, CaseIterable, Identifiable {
    case headings
    case formatting
    case structure
    case mathAndInsert
    case organize

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .headings: return LocalizedStringKey("Headings")
        case .formatting: return LocalizedStringKey("Formatting")
        case .structure: return LocalizedStringKey("Structure")
        case .mathAndInsert: return LocalizedStringKey("Math & Insert")
        case .organize: return LocalizedStringKey("Organize")
        }
    }
}

struct EditorActionItem: Identifiable {
    let id: String
    let symbol: String
    let titleKey: String
    let shortTitleKey: String?
    let shortcut: String?
    let category: EditorActionCategory
    let isSecondary: Bool
    let keywords: [String]
    let perform: @MainActor (EditorController) -> Void

    var localizedTitle: String {
        String(localized: String.LocalizationValue(titleKey))
    }

    var localizedShortTitle: String {
        if let short = shortTitleKey {
            return String(localized: String.LocalizationValue(short))
        }
        return localizedTitle
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if localizedTitle.lowercased().contains(q) { return true }
        if titleKey.lowercased().contains(q) { return true }
        if symbol.lowercased().contains(q) { return true }
        return keywords.contains { $0.lowercased().contains(q) }
    }
}

/// 所有编辑器快捷动作的单一事实来源：底栏按钮与「···」面板完全复用同一套执行语义。
@MainActor
enum EditorActionRegistry {

    static let allItems: [EditorActionItem] = [
        // Headings（统一使用 applyBlockPrefix 替换行首前缀）
        EditorActionItem(
            id: "heading1", symbol: "#", titleKey: "Major Heading", shortTitleKey: nil,
            shortcut: "⌃⌘1", category: .headings, isSecondary: false,
            keywords: ["h1", "heading", "title", "标题", "大标题"]
        ) { $0.applyBlockPrefix("# ") },
        EditorActionItem(
            id: "heading2", symbol: "##", titleKey: "Heading", shortTitleKey: nil,
            shortcut: "⌃⌘2", category: .headings, isSecondary: false,
            keywords: ["h2", "heading", "标题", "二级"]
        ) { $0.applyBlockPrefix("## ") },
        EditorActionItem(
            id: "heading3", symbol: "###", titleKey: "Subheading", shortTitleKey: nil,
            shortcut: "⌃⌘3", category: .headings, isSecondary: false,
            keywords: ["h3", "subheading", "副标题", "三级"]
        ) { $0.applyBlockPrefix("### ") },
        EditorActionItem(
            id: "heading4", symbol: "####", titleKey: "Heading 4", shortTitleKey: nil,
            shortcut: "⌃⌘4", category: .headings, isSecondary: true,
            keywords: ["h4", "heading", "四级"]
        ) { $0.applyBlockPrefix("#### ") },
        EditorActionItem(
            id: "clearPrefix", symbol: "¶", titleKey: "Plain Paragraph", shortTitleKey: nil,
            shortcut: nil, category: .headings, isSecondary: true,
            keywords: ["paragraph", "clear", "plain", "正文", "清除格式"]
        ) { $0.applyBlockPrefix("") },

        // Formatting
        EditorActionItem(
            id: "bold", symbol: "**", titleKey: "Bold", shortTitleKey: nil,
            shortcut: "⌘B", category: .formatting, isSecondary: false,
            keywords: ["strong", "bold", "加粗", "粗体"]
        ) { $0.toggleBold() },
        EditorActionItem(
            id: "italic", symbol: "*", titleKey: "Italic", shortTitleKey: nil,
            shortcut: "⌘I", category: .formatting, isSecondary: false,
            keywords: ["em", "italic", "斜体"]
        ) { $0.toggleItalic() },
        EditorActionItem(
            id: "strikethrough", symbol: "~~", titleKey: "Strikethrough", shortTitleKey: nil,
            shortcut: "⌃⌘U", category: .formatting, isSecondary: false,
            keywords: ["delete", "strike", "删除线"]
        ) { $0.toggleStrikethrough() },
        EditorActionItem(
            id: "inlineCode", symbol: "`", titleKey: "Inline Code", shortTitleKey: "Code",
            shortcut: "⇧⌘K", category: .formatting, isSecondary: false,
            keywords: ["code", "monospace", "行内代码", "代码"]
        ) { $0.toggleInlineCode() },
        EditorActionItem(
            id: "highlight", symbol: "==", titleKey: "Highlight", shortTitleKey: nil,
            shortcut: "⌃⌘H", category: .formatting, isSecondary: true,
            keywords: ["mark", "highlight", "高亮"]
        ) { $0.toggleHighlight() },

        // Structure（统一使用 applyBlockPrefix）
        EditorActionItem(
            id: "bulletList", symbol: "-", titleKey: "Bulleted List", shortTitleKey: "List",
            shortcut: "⌘L", category: .structure, isSecondary: false,
            keywords: ["list", "ul", "bullet", "无序列表", "列表"]
        ) { $0.applyBlockPrefix("- ") },
        EditorActionItem(
            id: "orderedList", symbol: "1.", titleKey: "Numbered List", shortTitleKey: nil,
            shortcut: "⇧⌘L", category: .structure, isSecondary: false,
            keywords: ["ol", "ordered", "number", "有序列表"]
        ) { $0.applyBlockPrefix("1. ") },
        EditorActionItem(
            id: "taskList", symbol: "[ ]", titleKey: "Task List", shortTitleKey: nil,
            shortcut: "⌥⌘L", category: .structure, isSecondary: false,
            keywords: ["todo", "checkbox", "task", "任务列表", "待办"]
        ) { $0.applyBlockPrefix("- [ ] ") },
        EditorActionItem(
            id: "blockquote", symbol: ">", titleKey: "Blockquote", shortTitleKey: nil,
            shortcut: "⌘'", category: .structure, isSecondary: false,
            keywords: ["quote", "blockquote", "引用"]
        ) { $0.applyBlockPrefix("> ") },
        EditorActionItem(
            id: "codeBlock", symbol: "```", titleKey: "Code Block", shortTitleKey: nil,
            shortcut: nil, category: .structure, isSecondary: false,
            keywords: ["fence", "code", "代码块"]
        ) { $0.toggleCodeBlock() },

        // Math & Insert
        EditorActionItem(
            id: "link", symbol: "[]", titleKey: "Link", shortTitleKey: nil,
            shortcut: "⌥⌘K", category: .mathAndInsert, isSecondary: false,
            keywords: ["url", "href", "link", "链接"]
        ) { $0.insertLinkMarkup() },
        EditorActionItem(
            id: "inlineMath", symbol: "$", titleKey: "Inline Math", shortTitleKey: "Math",
            shortcut: "⌃⌘M", category: .mathAndInsert, isSecondary: false,
            keywords: ["latex", "math", "formula", "equation", "公式", "数学", "行内公式"]
        ) { $0.insertInlineMath() },
        EditorActionItem(
            id: "displayMath", symbol: "$$", titleKey: "Display Math", shortTitleKey: "Math Block",
            shortcut: "⇧⌃⌘M", category: .mathAndInsert, isSecondary: false,
            keywords: ["latex", "math", "block", "equation", "块级公式", "数学块"]
        ) { $0.insertDisplayMath() },
        EditorActionItem(
            id: "image", symbol: "![", titleKey: "Image", shortTitleKey: nil,
            shortcut: nil, category: .mathAndInsert, isSecondary: true,
            keywords: ["img", "picture", "photo", "图片"]
        ) { $0.insertImageMarkup() },
        EditorActionItem(
            id: "table", symbol: "| |", titleKey: "Table", shortTitleKey: nil,
            shortcut: nil, category: .mathAndInsert, isSecondary: true,
            keywords: ["table", "grid", "表格"]
        ) { $0.insertTableTemplate() },
        EditorActionItem(
            id: "footnote", symbol: "[^]", titleKey: "Footnote", shortTitleKey: nil,
            shortcut: nil, category: .mathAndInsert, isSecondary: true,
            keywords: ["footnote", "note", "脚注"]
        ) { $0.insertFootnoteMarkup() },
        EditorActionItem(
            id: "divider", symbol: "---", titleKey: "Horizontal Rule", shortTitleKey: "Separator",
            shortcut: "⇧⌘-", category: .mathAndInsert, isSecondary: true,
            keywords: ["hr", "divider", "separator", "分割线"]
        ) { $0.insertMarkup("\n---\n") },

        // Organize
        EditorActionItem(
            id: "moveUp", symbol: "↑", titleKey: "Move Paragraph Up", shortTitleKey: nil,
            shortcut: "⌥⌘↑", category: .organize, isSecondary: true,
            keywords: ["move", "up", "paragraph", "reorder", "上移段落"]
        ) { $0.moveParagraphUp() },
        EditorActionItem(
            id: "moveDown", symbol: "↓", titleKey: "Move Paragraph Down", shortTitleKey: nil,
            shortcut: "⌥⌘↓", category: .organize, isSecondary: true,
            keywords: ["move", "down", "paragraph", "reorder", "下移段落"]
        ) { $0.moveParagraphDown() },
        EditorActionItem(
            id: "editEntity", symbol: "✎", titleKey: "Edit Link or Formula", shortTitleKey: nil,
            shortcut: "⌘E", category: .organize, isSecondary: true,
            keywords: ["edit", "entity", "popover", "编辑链接", "编辑公式"]
        ) { $0.activateEntityAtCaret() },
    ]

    static func item(id: String) -> EditorActionItem? {
        allItems.first { $0.id == id }
    }

    /// 根据 MDEditorKit 推送的 5 态作用域返回底栏快捷动作（精简 3 项 + ···）。
    static func quickItems(for context: EditorBlockContext) -> [EditorActionItem] {
        let ids: [String]
        switch context {
        case .empty(let suggestedLevel):
            // Scope 0（空行）：智能标题 + 无序列表 + 图片
            let headingID = headingItemID(for: suggestedLevel)
            ids = [headingID, "bulletList", "image"]
        case .paragraphText:
            // Scope 1（正文句中/段尾，无选区）：粗体 + 链接 + 行内公式
            ids = ["bold", "link", "inlineMath"]
        case .inlineText:
            // Scope 1（行内局部选区）：粗体 + 斜体 + 链接
            ids = ["bold", "italic", "link"]
        case .paragraphStart(let suggestedLevel), .fullLine(let suggestedLevel):
            // Scope 2 & 3（段落行首 / 单整行选区）：智能标题 + 无序列表 + 引用
            let headingID = headingItemID(for: suggestedLevel)
            ids = [headingID, "bulletList", "blockquote"]
        case .fullLines:
            // Scope 4（跨多段选区）：无序列表 + 引用 + 代码块
            ids = ["bulletList", "blockquote", "codeBlock"]
        case .headingLine:
            // Scope 2 细化（标题行首）：H1 / H2 / H3（再次点击已激活项清除标题）
            ids = ["heading1", "heading2", "heading3"]
        case .listLine:
            // Scope 2 细化（列表行首）：无序 / 有序 / 任务（再次点击已激活项退出列表）
            ids = ["bulletList", "orderedList", "taskList"]
        case .quoteLine:
            // Scope 2 细化（引用行首）：引用 / 列表 / 标题
            ids = ["blockquote", "bulletList", "heading2"]
        case .codeBlock:
            ids = ["inlineCode", "codeBlock", "divider"]
        case .mathBlock:
            return [
                EditorActionItem(
                    id: "mathFrac", symbol: "\\frac", titleKey: "Fraction", shortTitleKey: nil,
                    shortcut: nil, category: .mathAndInsert, isSecondary: false, keywords: []
                ) { $0.insertMarkup("\\frac{}{}") },
                EditorActionItem(
                    id: "mathSqrt", symbol: "\\sqrt", titleKey: "Square Root", shortTitleKey: nil,
                    shortcut: nil, category: .mathAndInsert, isSecondary: false, keywords: []
                ) { $0.insertMarkup("\\sqrt{}") },
                EditorActionItem(
                    id: "mathSum", symbol: "\\sum", titleKey: "Summation", shortTitleKey: nil,
                    shortcut: nil, category: .mathAndInsert, isSecondary: false, keywords: []
                ) { $0.insertMarkup("\\sum_{i=1}^{n}") },
            ]
        }
        return Array(ids.compactMap { item(id: $0) }.prefix(3))
    }

    /// 按当前作用域动态划分「···」命令面板的主/次列表。
    static func partitionedItems(for context: EditorBlockContext) -> (primary: [EditorActionItem], secondary: [EditorActionItem]) {
        let primaryIDs: [String]
        switch context {
        case .empty:
            primaryIDs = [
                "heading1", "heading2", "heading3",
                "bulletList", "orderedList", "taskList", "blockquote", "codeBlock",
                "image", "displayMath", "table", "divider"
            ]
        case .paragraphText:
            primaryIDs = [
                "bold", "italic", "strikethrough", "inlineCode", "highlight",
                "link", "inlineMath", "image", "footnote"
            ]
        case .inlineText:
            primaryIDs = [
                "bold", "italic", "strikethrough", "inlineCode", "highlight",
                "link", "inlineMath"
            ]
        case .paragraphStart, .fullLine, .headingLine, .listLine, .quoteLine:
            primaryIDs = [
                "heading1", "heading2", "heading3", "clearPrefix",
                "bulletList", "orderedList", "taskList", "blockquote", "codeBlock",
                "divider"
            ]
        case .fullLines:
            primaryIDs = [
                "bulletList", "orderedList", "taskList", "blockquote", "codeBlock",
                "displayMath", "divider", "moveUp", "moveDown"
            ]
        case .codeBlock:
            primaryIDs = ["inlineCode", "codeBlock", "divider", "clearPrefix"]
        case .mathBlock:
            primaryIDs = ["displayMath", "inlineMath", "editEntity", "divider"]
        }

        let primarySet = Set(primaryIDs)
        let primary = primaryIDs.compactMap { item(id: $0) }
        let secondary = allItems.filter { !primarySet.contains($0.id) }
        return (primary, secondary)
    }

    private static func headingItemID(for level: Int) -> String {
        switch level {
        case 2: return "heading2"
        case 3: return "heading3"
        default: return "heading1"
        }
    }

    /// 返回当前光标所在块对应的激活按钮 ID（用于高亮当前段落格式，再次点击可取消前缀）。
    static func activeItemID(for context: EditorBlockContext) -> String? {
        switch context {
        case .headingLine(let level):
            switch level {
            case 1: return "heading1"
            case 2: return "heading2"
            case 3: return "heading3"
            default: return nil
            }
        case .listLine(let kind):
            switch kind {
            case .unordered: return "bulletList"
            case .ordered: return "orderedList"
            case .task: return "taskList"
            }
        case .quoteLine:
            return "blockquote"
        default:
            return nil
        }
    }
}

// MARK: - 主视图（全宽底部停靠快捷栏）

struct EditorMarkupBar: View {
    @ObservedObject var controller: EditorController
    var backgroundColor: Color = Color(nsColor: .textBackgroundColor)
    var contentWidth: CGFloat = 750
    var isHiddenByOverlay: Bool = false

    @State private var displayedContext: EditorBlockContext = .empty(suggestedHeadingLevel: 1)
    @State private var debounceTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if !isHiddenByOverlay && !controller.isSearchVisible {
                VStack(spacing: 0) {
                    // 顶部柔和渐变淡出，让正文滚动到底部时自然隐入底栏而非生硬截断
                    LinearGradient(
                        colors: [backgroundColor.opacity(0), backgroundColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 14)
                    .allowsHitTesting(false)

                    // 停靠底栏主体：全宽纸面同色 + 对齐正文宽度的顶部极细分隔线 + 居中 3 项 + ···
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.09))
                            .frame(maxWidth: max(420, contentWidth))
                            .frame(height: 0.5)
                            .padding(.horizontal, 36)

                        HStack(spacing: 0) {
                            Spacer(minLength: 12)

                            HStack(spacing: 18) {
                                let activeID = EditorActionRegistry.activeItemID(for: displayedContext)

                                ForEach(EditorActionRegistry.quickItems(for: displayedContext)) { item in
                                    let isActive = (item.id == activeID)
                                    MarkupButton(
                                        symbol: item.symbol,
                                        label: item.localizedShortTitle,
                                        shortcut: item.shortcut,
                                        isActive: isActive
                                    ) {
                                        if isActive {
                                            // 再次点击当前激活的块级按钮，清除前缀回归普通正文
                                            controller.applyBlockPrefix("")
                                        } else {
                                            item.perform(controller)
                                        }
                                        controller.focusEditor()
                                    }
                                }

                                if let entity = controller.cursorContext.activeEntity {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.12))
                                        .frame(width: 0.5, height: 12)

                                    MarkupButton(
                                        symbol: entity.kind == .link ? "↗" : "∑",
                                        label: entityEditLabel(for: entity.kind),
                                        shortcut: "⌘E",
                                        isActive: true
                                    ) {
                                        controller.activeEntityForPopover = entity
                                    }
                                }

                                Rectangle()
                                    .fill(Color.primary.opacity(0.12))
                                    .frame(width: 0.5, height: 12)

                                moreButton
                            }
                            .id(displayedContext)
                            .transition(.opacity)

                            Spacer(minLength: 12)
                        }
                        .frame(height: 44)
                    }
                    .frame(maxWidth: .infinity)
                    .background(backgroundColor)
                    .background(QuickActionBarCursorGuard())
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.14), value: displayedContext)
        .animation(.easeInOut(duration: 0.18), value: isHiddenByOverlay || controller.isSearchVisible)
        .onReceive(controller.$cursorContext) { newContext in
            scheduleContextUpdate(newContext.blockContext)
        }
        .onAppear {
            displayedContext = controller.cursorContext.blockContext
        }
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    private func scheduleContextUpdate(_ next: EditorBlockContext) {
        guard next != displayedContext else { return }
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000) // 40ms 轻量防抖，兼顾跟手响应与无闪烁
            guard !Task.isCancelled else { return }
            displayedContext = next
        }
    }

    private func entityEditLabel(for kind: EditorEntityKind) -> String {
        switch kind {
        case .link: return String(localized: "Edit Link")
        case .image: return String(localized: "Edit Image")
        case .inlineMath, .displayMath: return String(localized: "Edit Formula")
        }
    }

    // MARK: - 更多按钮

    private var moreButton: some View {
        MoreMarkupButton(isPresented: $controller.showAllMarkupPopover) {
            EditorActionCommandPopover(controller: controller)
        }
    }
}

private struct MoreMarkupButton<PopoverContent: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let popoverContent: () -> PopoverContent
    @State private var isHovered = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered || isPresented ? .primary.opacity(0.85) : .secondary.opacity(0.6))
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(isHovered || isPresented ? 0.07 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(LocalizedStringKey("Show All Markup (⌘\\)"))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            popoverContent()
        }
    }
}

// MARK: - 空白区域防穿透 + 恢复默认箭头光标

private struct QuickActionBarCursorGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> CursorGuardNSView {
        CursorGuardNSView()
    }

    func updateNSView(_ nsView: CursorGuardNSView, context: Context) {}

    final class CursorGuardNSView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .arrow)
        }

        override func mouseDown(with event: NSEvent) {
            // 吞掉底栏空白点击，避免穿透到底层编辑器丢失选区
        }

        override func rightMouseDown(with event: NSEvent) {}
    }
}

// MARK: - Markup 按钮（极简排版风格）

struct MarkupButton: View {
    let symbol: String
    let label: String
    var shortcut: String? = nil
    var isActive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(symbol)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundColor(
                        isActive
                            ? .accentColor
                            : .secondary.opacity(isHovered ? 0.78 : 0.50)
                    )

                Text(label)
                    .font(.system(size: 12, weight: isActive ? .medium : .regular))
                    .lineLimit(1)
                    .foregroundColor(
                        isActive
                            ? .accentColor
                            : (isHovered ? .primary.opacity(0.92) : .secondary.opacity(0.80))
                    )
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5.5)
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(isHovered ? 0.16 : 0.10)
                            : Color.primary.opacity(isHovered ? 0.051 : 0)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(shortcut.map { "\(label) (\($0))" } ?? label)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 可搜索、全键盘驱动的命令面板

struct EditorActionCommandPopover: View {
    @ObservedObject var controller: EditorController
    @Environment(\.dismiss) private var dismiss

    @State private var filterText: String = ""
    @State private var showSecondary: Bool = false
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    private var partitioned: (primary: [EditorActionItem], secondary: [EditorActionItem]) {
        EditorActionRegistry.partitionedItems(for: controller.cursorContext.blockContext)
    }

    private var visibleItems: [EditorActionItem] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            // 有过滤词时搜索全量（主 + 次）动作
            return EditorActionRegistry.allItems.filter { $0.matches(query: query) }
        }
        let split = partitioned
        if showSecondary {
            return split.primary + split.secondary
        }
        return split.primary
    }

    private var hasCollapsedSecondary: Bool {
        filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !showSecondary
            && !partitioned.secondary.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部实时过滤栏
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))

                TextField(LocalizedStringKey("Filter markup..."), text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)
                    .onSubmit {
                        triggerSelectedItem()
                    }

                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.035))

            Divider().opacity(0.4)

            // 动作列表
            if visibleItems.isEmpty {
                Text(LocalizedStringKey("No matching markup"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 22)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                                if shouldShowSectionHeader(at: index) {
                                    Text(item.category.localizedTitle)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .textCase(.uppercase)
                                        .padding(.horizontal, 12)
                                        .padding(.top, index == 0 ? 6 : 10)
                                        .padding(.bottom, 2)
                                }

                                ActionCommandRow(
                                    item: item,
                                    filterText: filterText,
                                    isSelected: index == selectedIndex
                                ) {
                                    execute(item)
                                }
                                .id(item.id)
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                            }

                            if hasCollapsedSecondary {
                                Divider()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showSecondary = true
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Text(LocalizedStringKey("More Markup..."))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: selectedIndex) { _, newIdx in
                        if newIdx >= 0 && newIdx < visibleItems.count {
                            proxy.scrollTo(visibleItems[newIdx].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 248)
        .onAppear {
            selectedIndex = 0
            isSearchFocused = true
        }
        .onChange(of: filterText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            guard !visibleItems.isEmpty else { return .ignored }
            selectedIndex = (selectedIndex - 1 + visibleItems.count) % visibleItems.count
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !visibleItems.isEmpty else { return .ignored }
            selectedIndex = (selectedIndex + 1) % visibleItems.count
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            controller.focusEditor()
            return .handled
        }
    }

    private func shouldShowSectionHeader(at index: Int) -> Bool {
        guard filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if index == 0 { return true }
        return visibleItems[index].category != visibleItems[index - 1].category
    }

    private func triggerSelectedItem() {
        guard selectedIndex >= 0 && selectedIndex < visibleItems.count else { return }
        execute(visibleItems[selectedIndex])
    }

    private func execute(_ item: EditorActionItem) {
        dismiss()
        item.perform(controller)
        controller.focusEditor()
    }
}

private struct ActionCommandRow: View {
    let item: EditorActionItem
    let filterText: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(item.symbol)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.55))
                    .frame(width: 26, alignment: .leading)

                highlightedLabel
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer()

                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var highlightedLabel: Text {
        let title = item.localizedTitle
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let range = title.range(of: query, options: .caseInsensitive) else {
            return Text(title)
        }
        let prefix = String(title[..<range.lowerBound])
        let match = String(title[range])
        let suffix = String(title[range.upperBound...])
        return Text(prefix) + Text(match).bold().foregroundColor(.accentColor) + Text(suffix)
    }
}
