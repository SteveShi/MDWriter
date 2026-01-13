//
//  MarkdownTextStorage.swift
//  MDWriter
//
//  简化版 Markdown 渲染 - 使用正则表达式
//

import AppKit

class MarkdownTextStorage: NSTextStorage {

    // MARK: - Properties

    private let backingStore = NSMutableAttributedString()

    var theme: AppTheme = .light
    var baseFont: NSFont = NSFont(name: "PingFang SC", size: 17) ?? .systemFont(ofSize: 17)
    var lineHeightMultiple: CGFloat = 1.7
    var paragraphSpacing: CGFloat = 12.0

    var isComposing: Bool = false
    private var isHighlighting: Bool = false

    // MARK: - Colors

    private var textColor: NSColor {
        theme == .light ? NSColor(white: 0.15, alpha: 1.0) : NSColor(white: 0.88, alpha: 1.0)
    }

    private var headingColor: NSColor {
        theme == .light ? NSColor.black : NSColor.white
    }

    private var markupColor: NSColor {
        // 深色模式下更亮，浅色模式下更淡
        theme == .light ? NSColor(white: 0.5, alpha: 1.0) : NSColor(white: 0.5, alpha: 1.0)
    }

    private var linkColor: NSColor {
        NSColor.systemBlue
    }

    private var codeColor: NSColor {
        theme == .light
            ? NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
            : NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
    }

    private var codeBackground: NSColor {
        theme == .light ? NSColor(white: 0.95, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
    }

    // MARK: - NSTextStorage Primitives

    override var string: String { backingStore.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?)
        -> [NSAttributedString.Key: Any]
    {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(
            .editedCharacters, range: range, changeInLength: (str as NSString).length - range.length
        )
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Processing

    override func processEditing() {
        if editedMask.contains(.editedCharacters) && !isHighlighting && !isComposing {
            performHighlighting()
        }
        super.processEditing()
    }

    func forceHighlight() {
        if !isComposing {
            performHighlighting()
        }
    }

    // MARK: - Highlighting (Regex-based)

    private func performHighlighting() {
        guard length > 0 else { return }
        isHighlighting = true

        let wholeRange = NSRange(location: 0, length: length)
        let text = string as NSString

        // 1. 重置所有属性
        backingStore.removeAttribute(.font, range: wholeRange)
        backingStore.removeAttribute(.foregroundColor, range: wholeRange)
        backingStore.removeAttribute(.paragraphStyle, range: wholeRange)
        backingStore.removeAttribute(.backgroundColor, range: wholeRange)
        backingStore.removeAttribute(.strikethroughStyle, range: wholeRange)
        backingStore.removeAttribute(.underlineStyle, range: wholeRange)

        // 2. 应用基础样式
        let baseStyle = NSMutableParagraphStyle()
        baseStyle.lineHeightMultiple = lineHeightMultiple
        baseStyle.paragraphSpacing = paragraphSpacing

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: baseStyle,
        ]
        backingStore.addAttributes(baseAttributes, range: wholeRange)

        // 3. 逐行处理标题
        text.enumerateSubstrings(in: wholeRange, options: [.byLines, .substringNotRequired]) {
            _, lineRange, _, _ in
            self.styleHeading(in: lineRange, text: text)
        }

        // 4. 处理内联样式
        styleBold(text: text, range: wholeRange)
        styleItalic(text: text, range: wholeRange)
        styleInlineCode(text: text, range: wholeRange)
        styleLinks(text: text, range: wholeRange)
        styleStrikethrough(text: text, range: wholeRange)

        isHighlighting = false
    }

    // MARK: - Heading Styling (Ulysses-style)

    private func styleHeading(in lineRange: NSRange, text: NSString) {
        let lineString = text.substring(with: lineRange)

        // 匹配标题：# 开头
        guard lineString.hasPrefix("#") else { return }

        // 计算标题级别
        var level = 0
        for char in lineString {
            if char == "#" { level += 1 } else { break }
        }

        guard level >= 1 && level <= 6 else { return }

        // 检查 # 后是否有空格和内容
        let afterHash = String(lineString.dropFirst(level))
        guard afterHash.hasPrefix(" ") || afterHash.isEmpty else { return }

        // 字体大小倍数 (Ulysses 风格：一级标题特别大)
        let sizeMultiplier: CGFloat
        switch level {
        case 1: sizeMultiplier = 2.0
        case 2: sizeMultiplier = 1.6
        case 3: sizeMultiplier = 1.35
        case 4: sizeMultiplier = 1.2
        default: sizeMultiplier = 1.1
        }

        // ===== 文字部分：大号粗体 =====
        let contentStart = lineRange.location + level + 1  // 跳过 "# "
        let contentLength = lineRange.length - level - 1

        if contentLength > 0 {
            let contentRange = NSRange(location: contentStart, length: contentLength)
            let fontSize = baseFont.pointSize * sizeMultiplier
            let headingFont: NSFont
            if let pingFang = NSFont(name: "PingFang SC", size: fontSize) {
                headingFont = NSFontManager.shared.convert(pingFang, toHaveTrait: .boldFontMask)
            } else {
                headingFont = NSFont.boldSystemFont(ofSize: fontSize)
            }
            backingStore.addAttribute(.font, value: headingFont, range: contentRange)
            backingStore.addAttribute(.foregroundColor, value: headingColor, range: contentRange)
        }

        // ===== # 符号部分：固定大小、底部对齐、淡色 =====
        let hashRange = NSRange(location: lineRange.location, length: level + 1)
        if hashRange.location + hashRange.length <= length {
            // 固定字体大小(与基础字体的 70%)
            let symbolSize = baseFont.pointSize * 0.7
            let symbolFont = NSFont.systemFont(ofSize: symbolSize, weight: .regular)
            backingStore.addAttribute(.font, value: symbolFont, range: hashRange)
            // 淡色但可见
            backingStore.addAttribute(.foregroundColor, value: markupColor, range: hashRange)
            // 不设置 baselineOffset，保持底部对齐
        }

        // 段落样式
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.4
        style.paragraphSpacingBefore = CGFloat(24 - level * 3)
        style.paragraphSpacing = 6
        backingStore.addAttribute(.paragraphStyle, value: style, range: lineRange)
    }

    // MARK: - Bold Styling (**text**)

    private func styleBold(text: NSString, range: NSRange) {
        let pattern = "\\*\\*(.+?)\\*\\*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        regex.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            // 粗体字体
            let boldFont = NSFontManager.shared.convert(self.baseFont, toHaveTrait: .boldFontMask)
            self.backingStore.addAttribute(.font, value: boldFont, range: matchRange)

            // 淡化 ** 符号
            let openRange = NSRange(location: matchRange.location, length: 2)
            let closeRange = NSRange(
                location: matchRange.location + matchRange.length - 2, length: 2)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.markupColor, range: openRange)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.markupColor, range: closeRange)
        }
    }

    // MARK: - Italic Styling (*text*)

    private func styleItalic(text: NSString, range: NSRange) {
        // 使用负向前瞻排除 ** 的情况
        let pattern = "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        regex.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            // 斜体字体
            let italicFont = NSFontManager.shared.convert(
                self.baseFont, toHaveTrait: .italicFontMask)
            self.backingStore.addAttribute(.font, value: italicFont, range: matchRange)

            // 淡化 * 符号
            let openRange = NSRange(location: matchRange.location, length: 1)
            let closeRange = NSRange(
                location: matchRange.location + matchRange.length - 1, length: 1)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.markupColor, range: openRange)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.markupColor, range: closeRange)
        }
    }

    // MARK: - Inline Code Styling (`code`)

    private func styleInlineCode(text: NSString, range: NSRange) {
        let pattern = "`([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        regex.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            // 等宽字体
            let monoFont = NSFont.monospacedSystemFont(
                ofSize: self.baseFont.pointSize * 0.9, weight: .regular)
            self.backingStore.addAttribute(.font, value: monoFont, range: matchRange)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.codeColor, range: matchRange)
            self.backingStore.addAttribute(
                .backgroundColor, value: self.codeBackground, range: matchRange)
        }
    }

    // MARK: - Link Styling [text](url)

    private func styleLinks(text: NSString, range: NSRange) {
        let pattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        regex.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range,
                let textRange = match?.range(at: 1)
            else { return }

            // 链接文本着色
            self.backingStore.addAttribute(
                .foregroundColor, value: self.linkColor, range: textRange)
            self.backingStore.addAttribute(
                .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)

            // 淡化 []() 部分
            let bracketOpen = NSRange(location: matchRange.location, length: 1)
            let bracketClose = NSRange(location: textRange.location + textRange.length, length: 1)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.markupColor, range: bracketOpen)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.markupColor, range: bracketClose)

            // URL 部分完全淡化
            let urlStart = textRange.location + textRange.length + 1
            let urlLength = matchRange.location + matchRange.length - urlStart
            if urlLength > 0 {
                let urlRange = NSRange(location: urlStart, length: urlLength)
                self.backingStore.addAttribute(
                    .foregroundColor, value: self.markupColor.withAlphaComponent(0.6),
                    range: urlRange)
            }
        }
    }

    // MARK: - Strikethrough Styling (~~text~~)

    private func styleStrikethrough(text: NSString, range: NSRange) {
        let pattern = "~~(.+?)~~"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        regex.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }

            self.backingStore.addAttribute(
                .strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
            self.backingStore.addAttribute(
                .foregroundColor, value: self.markupColor, range: matchRange)
        }
    }
}
