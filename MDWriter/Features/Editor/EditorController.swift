//
//  EditorController.swift
//  MDWriter
//

import AppKit
import Combine
import Foundation
import MDEditorKit

class EditorController: ObservableObject {

    // MARK: - Proxy Instance

    /// 编辑器交互代理
    let proxy = MDEditorProxy()

    // MARK: - Published State

    @Published var isMarkupBarVisible: Bool = false
    @Published var isSearchVisible: Bool = false

    // Search & Replace State
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var isReplaceVisible: Bool = false

    // Selection State —— 由 MDEditor 1.7.1+ 的 onSelectionChange 实时驱动，
    // 供上下文敏感的快捷输入栏订阅。
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @Published var fullText: String = ""

    /// 编辑器文本统计 —— 由 MDEditor 1.8.0 的 onTextChange 实时驱动。
    @Published var stats: EditorStats = EditorStats(
        characterCount: 0, wordCount: 0, lineCount: 0)

    // MARK: - Init

    init() {
        // 选区 / 光标变化
        proxy.onSelectionChange = { [weak self] range, text in
            guard let self = self else { return }
            self.selectedRange = range
            self.fullText = text
        }
        // 文本变化（驱动统计快照，避免每次 UI 查询时重新计算全文）
        proxy.onTextChange = { [weak self] _ in
            guard let self = self else { return }
            self.stats = self.proxy.stats()
        }
    }

    // MARK: - Basic Insert

    func insert(_ text: String) {
        proxy.insert(text)
    }

    func insertMarkup(_ markup: String) {
        proxy.insert(markup)
    }

    // MARK: - Block-level Prefix Switching (Ulysses-style)

    /// 将光标所在行的 block 前缀替换为 `prefix`，剥离已有的 heading / 列表 / 引用前缀。
    /// - Parameter prefix: 新前缀，含尾随空格，如 `"## "`、`"- "`、`"1. "`、`"- [ ] "`、`"> "`。
    ///                     传 `""` 表示去掉所有 block 前缀（变回普通段落）。
    func applyBlockPrefix(_ prefix: String) {
        // 直接使用 MDEditor 1.8.0 提供的行级 helper，避免外部再算一次 lineRange。
        let lineRange = proxy.getCurrentLineRange()
        var line = proxy.getCurrentLineText()
        let selection = proxy.getSelectedRange()

        // 保留行尾换行符；切换前缀只影响行内文本。
        var trailingNewline = ""
        if line.hasSuffix("\r\n") {
            trailingNewline = "\r\n"
            line = String(line.dropLast(2))
        } else if line.hasSuffix("\n") {
            trailingNewline = "\n"
            line = String(line.dropLast())
        }

        // 拆出行首缩进（空格 / Tab），block 前缀替换只影响缩进后的部分。
        let leadingWhitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let afterIndent = String(line.dropFirst(leadingWhitespace.count))
        let body = Self.stripBlockPrefix(afterIndent)

        let newLine = leadingWhitespace + prefix + body + trailingNewline
        proxy.replaceCurrentLine(with: newLine)

        // 把光标维持在"正文的相对偏移"上，避免跳到行首打断输入。
        let oldPrefixLen = (afterIndent as NSString).length - (body as NSString).length
        let caretOffsetInBody = max(
            0,
            selection.location - lineRange.location
                - (leadingWhitespace as NSString).length - oldPrefixLen
        )
        let clampedOffset = min((body as NSString).length, caretOffsetInBody)
        let newCursor =
            lineRange.location + (leadingWhitespace as NSString).length
            + (prefix as NSString).length + clampedOffset
        proxy.setSelectedRange(NSRange(location: newCursor, length: 0))
    }

    /// 剥离 Markdown 行首的 block 前缀（ATX heading / 任务列表 / 无序列表 / 有序列表 / 引用）。
    /// 不影响缩进——调用方应先拆出 leading whitespace。
    static func stripBlockPrefix(_ s: String) -> String {
        // 顺序很重要：task list 必须在普通无序列表之前匹配。
        let patterns = [
            #"^#{1,6}[ \t]+"#,             // # / ## / ... heading
            #"^-[ \t]\[[ xX]\][ \t]+"#,    // - [ ] task list
            #"^[-*+][ \t]+"#,              // - / * / + bulleted
            #"^\d+\.[ \t]+"#,              // 1. numbered
            #"^>+[ \t]?"#,                 // > / >> blockquote
        ]
        for pattern in patterns {
            if let match = s.range(of: pattern, options: .regularExpression) {
                return String(s[match.upperBound...])
            }
        }
        return s
    }

    // MARK: - Formatting Toggles (Wrapping)

    func toggleBold() {
        proxy.wrapSelection(prefix: "**", suffix: "**")
    }

    func toggleItalic() {
        proxy.wrapSelection(prefix: "*", suffix: "*")
    }

    func toggleStrikethrough() {
        proxy.wrapSelection(prefix: "~~", suffix: "~~")
    }

    func toggleInlineCode() {
        proxy.wrapSelection(prefix: "`", suffix: "`")
    }

    func toggleCodeBlock() {
        proxy.wrapSelection(prefix: "```\n", suffix: "\n```")
    }

    // MARK: - Special Inserts

    func insertLinkMarkup() {
        if let selectedText = proxy.getSelectedText(), !selectedText.isEmpty {
            proxy.insert("[\(selectedText)](url)")
        } else {
            proxy.insert("[text](url)")
        }
    }

    func insertImageMarkup() {
        proxy.insert("![alt text](image_url)")
    }

    /// 插入一张 NSImage —— 透过 EditorConfiguration.imageSaver 完成落盘，
    /// 编辑器会自动写入 `![alt](filename)`。宿主未配置 imageSaver 时不插入任何内容。
    func insertImage(_ image: NSImage, altText: String = "") {
        proxy.insertImage(image, altText: altText)
    }

    // MARK: - Markup Bar Toggle

    func toggleMarkupBar() {
        isMarkupBarVisible.toggle()
    }

    // MARK: - Find & Replace Methods

    func findNext() {
        proxy.findNext(text: searchText)
    }

    func findPrevious() {
        proxy.findPrevious(text: searchText)
    }

    func replace() {
        proxy.replace(search: searchText, with: replaceText)
    }

    func replaceAll() {
        proxy.replaceAll(search: searchText, with: replaceText)
    }

    // MARK: - Undo / Redo

    func undo() { proxy.undo() }
    func redo() { proxy.redo() }
    var canUndo: Bool { proxy.canUndo }
    var canRedo: Bool { proxy.canRedo }

    // MARK: - Focus

    /// 让编辑器拿回第一响应者身份（例如关闭 Find Bar 后回到正文）。
    func focusEditor() { proxy.focus() }
    func resignEditorFocus() { proxy.resignFocus() }

    // MARK: - Scroll

    func scrollRangeToVisible(_ range: NSRange) { proxy.scrollRangeToVisible(range) }
    func scrollToTop() { proxy.scrollToTop() }
    func scrollToBottom() { proxy.scrollToBottom() }

    // MARK: - Selection Helpers

    func selectAll() { proxy.selectAll() }
    func selectCurrentLine() { proxy.selectLine() }
    func selectCurrentParagraph() { proxy.selectParagraph() }

    // MARK: - Caret Geometry

    /// 当前光标在所属窗口坐标系内的矩形，可用于浮动气泡或内联补全弹层定位。
    func caretFrameInWindow() -> CGRect? { proxy.caretFrameInWindow() }
}
