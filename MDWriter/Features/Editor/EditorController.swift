//
//  EditorController.swift
//  MDWriter
//

import AppKit
import Combine
import Foundation
import MDEditorKit

@MainActor
class EditorController: ObservableObject {

    // MARK: - Proxy Instance

    /// 编辑器交互代理
    let proxy = MDEditorProxy()

    // MARK: - Published State

    @Published var isMarkupBarVisible: Bool = false
    @Published var showAllMarkupPopover: Bool = false
    @Published var isSearchVisible: Bool = false

    // Search & Replace State
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var isReplaceVisible: Bool = false

    // 轻量光标上下文 —— 由 MDEditorKit 的 onCursorContextChange 实时驱动（零全文重构）
    @Published var cursorContext: EditorCursorContext = EditorCursorContext()
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @Published var fullText: String = ""

    /// 当前激活的内联实体编辑气泡（点击数学公式/图片或 ⌘E 呼出）
    @Published var activeEntityForPopover: EditorEntityInfo? = nil

    /// 编辑器文本统计 —— 由 onTextChange 实时驱动
    @Published var stats: EditorStats = EditorStats(
        characterCount: 0, wordCount: 0, lineCount: 0)

    // MARK: - Init

    init() {
        // 轻量光标上下文变化（不再在每次方向键移动时重构全文 Markdown）
        proxy.onCursorContextChange = { [weak self] context in
            guard let self = self else { return }
            self.cursorContext = context
            self.selectedRange = context.selectedRange
        }

        // 内联实体激活（点击公式/图片附件、Command+点击链接或 ⌘E）
        proxy.onEntityActivate = { [weak self] entity in
            guard let self = self else { return }
            self.activeEntityForPopover = entity
        }

        // 文本变化（复用已还原的 Markdown 字符串，驱动统计与 GhostText）
        proxy.onTextChange = { [weak self] text in
            guard let self = self else { return }
            self.fullText = text
            self.stats = self.proxy.stats()
        }
    }

    /// 切换文档时同步初始正文，避免首次打开未编辑前 `fullText` 为空。
    func syncInitialText(_ text: String) {
        self.fullText = text
        self.activeEntityForPopover = nil
    }

    // MARK: - Basic Insert

    func insert(_ text: String) {
        proxy.insert(text)
    }

    func insertMarkup(_ markup: String) {
        proxy.insert(markup)
    }

    // MARK: - Block-level Prefix Switching

    /// 将光标所在行的 block 前缀替换为 `prefix`，剥离已有的 heading / 列表 / 引用前缀。
    func applyBlockPrefix(_ prefix: String) {
        let lineRange = proxy.getCurrentLineRange()
        var line = proxy.getCurrentLineText()
        let selection = proxy.getSelectedRange()

        var trailingNewline = ""
        if line.hasSuffix("\r\n") {
            trailingNewline = "\r\n"
            line = String(line.dropLast(2))
        } else if line.hasSuffix("\n") {
            trailingNewline = "\n"
            line = String(line.dropLast())
        }

        let leadingWhitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let afterIndent = String(line.dropFirst(leadingWhitespace.count))
        let body = Self.stripBlockPrefix(afterIndent)

        let newLine = leadingWhitespace + prefix + body + trailingNewline
        proxy.replaceCurrentLine(with: newLine)

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

    /// 剥离 Markdown 行首的 block 前缀。
    static func stripBlockPrefix(_ s: String) -> String {
        let patterns = [
            #"^#{1,6}[ \t]+"#,
            #"^-[ \t]\[[ xX]\][ \t]+"#,
            #"^[-*+][ \t]+"#,
            #"^\d+\.[ \t]+"#,
            #"^>+[ \t]?"#,
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

    func toggleHighlight() {
        proxy.wrapSelection(prefix: "==", suffix: "==")
    }

    func toggleInlineCode() {
        proxy.wrapSelection(prefix: "`", suffix: "`")
    }

    func toggleCodeBlock() {
        proxy.wrapSelection(prefix: "```\n", suffix: "\n```")
    }

    // MARK: - Math & Special Inserts

    func insertInlineMath(_ expression: String = "") {
        proxy.insertInlineMath(expression)
    }

    func insertDisplayMath(_ expression: String = "") {
        proxy.insertDisplayMath(expression)
    }

    func insertLinkMarkup() {
        if let selectedText = proxy.getSelectedText(), !selectedText.isEmpty {
            proxy.insert("[\(selectedText)](https://)")
        } else {
            proxy.insert("[text](https://)")
        }
    }

    func insertImageMarkup() {
        proxy.insert("![alt text](image_url)")
    }

    func insertTableTemplate() {
        let table = """
        | Column 1 | Column 2 |
        | --- | --- |
        | Value 1 | Value 2 |
        """
        proxy.insert(table)
    }

    func insertFootnoteMarkup() {
        proxy.insert("[^1]")
    }

    func insertImage(_ image: NSImage, altText: String = "") {
        proxy.insertImage(image, altText: altText)
    }

    // MARK: - Paragraph Movement & Entity Editing

    func moveParagraphUp() {
        proxy.moveParagraphUp()
    }

    func moveParagraphDown() {
        proxy.moveParagraphDown()
    }

    func activateEntityAtCaret() {
        proxy.activateEntityAtCaret()
    }

    /// 将内联实体气泡的编辑结果写回编辑器对应区间。
    func applyEntityEdit(entity: EditorEntityInfo, newSource: String) {
        proxy.replace(range: entity.range, with: newSource)
        activeEntityForPopover = nil
        focusEditor()
    }

    /// 插入 WikiLink 补全结果，替换未闭合的 `[[query`。
    func insertWikiLink(title: String, replacing query: EditorWikiLinkQuery) {
        let replacement = "[[\(title)]]"
        proxy.replace(range: query.replaceRange, with: replacement)
        let caret = query.replaceRange.location + (replacement as NSString).length
        proxy.setSelectedRange(NSRange(location: caret, length: 0))
        focusEditor()
    }

    // MARK: - Markup Bar Toggle

    func toggleMarkupBar() {
        isMarkupBarVisible.toggle()
    }

    // MARK: - Find & Replace Methods

    func findNext() { proxy.findNext(text: searchText) }
    func findPrevious() { proxy.findPrevious(text: searchText) }
    func replace() { proxy.replace(search: searchText, with: replaceText) }
    func replaceAll() { proxy.replaceAll(search: searchText, with: replaceText) }

    // MARK: - Undo / Redo

    func undo() { proxy.undo() }
    func redo() { proxy.redo() }
    var canUndo: Bool { proxy.canUndo }
    var canRedo: Bool { proxy.canRedo }

    // MARK: - Focus

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

    func caretFrameInWindow() -> CGRect? { proxy.caretFrameInWindow() }
}
