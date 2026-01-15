//
//  MarkdownTextStorage.swift
//  MDWriter
//
//  简化版 Markdown 渲染 - 使用正则表达式和 Highlightr
//

import AppKit
@preconcurrency import Highlightr

// 标记为 nonisolated 以避免 init 隔离冲突
// 标记为 @unchecked Sendable 以允许在 MainActor.assumeIsolated 中捕获 self
nonisolated class MarkdownTextStorage: NSTextStorage, @unchecked Sendable {

    // MARK: - 属性 (nonisolated(unsafe) 允许在非隔离方法中访问)

    nonisolated(unsafe) private let backingStore = NSMutableAttributedString()
    // 强制解包，以防 Highlightr() 初始化失败
    nonisolated(unsafe) private let highlightr = Highlightr()!
    nonisolated(unsafe) private var currentHighlightrThemeName: String?

    nonisolated(unsafe) var theme: AppTheme = .light
    nonisolated(unsafe) var baseFont: NSFont = NSFont(name: "PingFang SC", size: 17) ?? .systemFont(ofSize: 17)
    nonisolated(unsafe) var lineHeightMultiple: CGFloat = 1.7
    nonisolated(unsafe) var paragraphSpacing: CGFloat = 12.0

    nonisolated(unsafe) var isComposing: Bool = false
    nonisolated(unsafe) private var isHighlighting: Bool = false

    // MARK: - 正则表达式缓存 (使用 Raw Strings 确保转义正确)

    private enum Regex {
        static let bold = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#)
        static let italic = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#)
        static let inlineCode = try! NSRegularExpression(pattern: #"`([^"]+)`"#)
        static let links = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
        static let strikethrough = try! NSRegularExpression(pattern: #"~~(.+?)~~"#)
        static let codeBlocks = try! NSRegularExpression(pattern: #"```([a-zA-Z0-9+\-]*)\n([\s\S]*?)```"#)
    }

    // MARK: - 初始化器

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        super.init(pasteboardPropertyList: propertyList, ofType: type)
    }

    // MARK: - 颜色

    private var textColor: NSColor {
        theme == .light ? NSColor(white: 0.15, alpha: 1.0) : NSColor(white: 0.88, alpha: 1.0)
    }

    private var headingColor: NSColor {
        theme == .light ? NSColor.black : NSColor.white
    }

    private var markupColor: NSColor {
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

    // MARK: - NSTextStorage 基本方法覆盖

    override var string: String { backingStore.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - 编辑处理

    override func processEditing() {
        // 在 Swift 6 中，虽然我们是 nonisolated，但我们知道这个调用通常发生在主线程。
        // 由于所有属性都是 nonisolated(unsafe)，我们可以直接访问。
        // 这里的 self 捕获现在是安全的，因为我们声明了 @unchecked Sendable。
        
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

    // MARK: - 高亮处理

    private func performHighlighting() {
        guard length > 0 else { return }
        isHighlighting = true

        let wholeRange = NSRange(location: 0, length: length)
        let text = string as NSString

        backingStore.removeAttribute(.font, range: wholeRange)
        backingStore.removeAttribute(.foregroundColor, range: wholeRange)
        backingStore.removeAttribute(.paragraphStyle, range: wholeRange)
        backingStore.removeAttribute(.backgroundColor, range: wholeRange)
        backingStore.removeAttribute(.strikethroughStyle, range: wholeRange)
        backingStore.removeAttribute(.underlineStyle, range: wholeRange)

        let baseStyle = NSMutableParagraphStyle()
        baseStyle.lineHeightMultiple = lineHeightMultiple
        baseStyle.paragraphSpacing = paragraphSpacing

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: baseStyle,
        ]
        backingStore.addAttributes(baseAttributes, range: wholeRange)

        text.enumerateSubstrings(in: wholeRange, options: [.byLines, .substringNotRequired]) {
            _, lineRange, _, _ in
            self.styleHeading(in: lineRange, text: text)
        }

        styleBold(text: text, range: wholeRange)
        styleItalic(text: text, range: wholeRange)
        styleInlineCode(text: text, range: wholeRange)
        styleLinks(text: text, range: wholeRange)
        styleStrikethrough(text: text, range: wholeRange)
        styleCodeBlocks(text: text, range: wholeRange)

        isHighlighting = false
    }

    // MARK: - 样式处理辅助方法 (添加了 Range 检查以防止崩溃)

    private func safeAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        if NSMaxRange(range) <= length {
            backingStore.addAttribute(name, value: value, range: range)
        }
    }

    private func styleHeading(in lineRange: NSRange, text: NSString) {
        let lineString = text.substring(with: lineRange)
        guard lineString.hasPrefix("#") else { return }

        var level = 0
        for char in lineString {
            if char == "#" { level += 1 } else { break }
        }
        guard level >= 1 && level <= 6 else { return }

        let afterHash = String(lineString.dropFirst(level))
        guard afterHash.hasPrefix(" ") || afterHash.isEmpty else { return }

        let sizeMultiplier: CGFloat
        switch level {
        case 1: sizeMultiplier = 2.0
        case 2: sizeMultiplier = 1.6
        case 3: sizeMultiplier = 1.35
        case 4: sizeMultiplier = 1.2
        default: sizeMultiplier = 1.1
        }

        let contentStart = lineRange.location + level + 1
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
            safeAddAttribute(.font, value: headingFont, range: contentRange)
            safeAddAttribute(.foregroundColor, value: headingColor, range: contentRange)
        }

        let hashRange = NSRange(location: lineRange.location, length: level + 1)
        if hashRange.location + hashRange.length <= length {
            let symbolSize = baseFont.pointSize * 0.7
            let symbolFont = NSFont.systemFont(ofSize: symbolSize, weight: .regular)
            safeAddAttribute(.font, value: symbolFont, range: hashRange)
            safeAddAttribute(.foregroundColor, value: markupColor, range: hashRange)
        }

        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.4
        style.paragraphSpacingBefore = CGFloat(24 - level * 3)
        style.paragraphSpacing = 6
        safeAddAttribute(.paragraphStyle, value: style, range: lineRange)
    }

    private func styleBold(text: NSString, range: NSRange) {
        Regex.bold.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            let boldFont = NSFontManager.shared.convert(self.baseFont, toHaveTrait: .boldFontMask)
            safeAddAttribute(.font, value: boldFont, range: matchRange)
            let openRange = NSRange(location: matchRange.location, length: 2)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: openRange)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: closeRange)
        }
    }

    private func styleItalic(text: NSString, range: NSRange) {
        Regex.italic.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            let italicFont = NSFontManager.shared.convert(self.baseFont, toHaveTrait: .italicFontMask)
            safeAddAttribute(.font, value: italicFont, range: matchRange)
            let openRange = NSRange(location: matchRange.location, length: 1)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: openRange)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: closeRange)
        }
    }

    private func styleInlineCode(text: NSString, range: NSRange) {
        Regex.inlineCode.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            let monoFont = NSFont.monospacedSystemFont(ofSize: self.baseFont.pointSize * 0.9, weight: .regular)
            safeAddAttribute(.font, value: monoFont, range: matchRange)
            safeAddAttribute(.foregroundColor, value: self.codeColor, range: matchRange)
            safeAddAttribute(.backgroundColor, value: self.codeBackground, range: matchRange)
        }
    }

    private func styleLinks(text: NSString, range: NSRange) {
        Regex.links.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let textRange = match?.range(at: 1) else { return }
            safeAddAttribute(.foregroundColor, value: self.linkColor, range: textRange)
            safeAddAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            let bracketOpen = NSRange(location: matchRange.location, length: 1)
            let bracketClose = NSRange(location: textRange.location + textRange.length, length: 1)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: bracketOpen)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: bracketClose)
            let urlStart = textRange.location + textRange.length + 1
            let urlLength = matchRange.location + matchRange.length - urlStart
            if urlLength > 0 {
                let urlRange = NSRange(location: urlStart, length: urlLength)
                safeAddAttribute(.foregroundColor, value: self.markupColor.withAlphaComponent(0.6), range: urlRange)
            }
        }
    }

    private func styleStrikethrough(text: NSString, range: NSRange) {
        Regex.strikethrough.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            safeAddAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: matchRange)
        }
    }

    private func styleCodeBlocks(text: NSString, range: NSRange) {
        let highlightr = self.highlightr
        let targetTheme = (self.theme == .dark) ? "monokai-sublime" : "xcode"
        if currentHighlightrThemeName != targetTheme {
            if highlightr.setTheme(to: targetTheme) {
                currentHighlightrThemeName = targetTheme
            }
        }

        Regex.codeBlocks.enumerateMatches(in: text as String, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range, let langRange = match?.range(at: 1), let codeRange = match?.range(at: 2) else { return }
            let language = text.substring(with: langRange)
            let code = text.substring(with: codeRange)
            
            // 安全检查：如果 Highlightr 返回 nil，或者长度不匹配（可能发生了 HTML 转义），则跳过语法高亮，只渲染背景
            let highlighted = language.isEmpty ? highlightr.highlight(code) : highlightr.highlight(code, as: language)
            
            // 只有当高亮后的文本长度与原始内容一致时，才应用颜色，否则会导致 Range 越界崩溃
            if let highlightedCode = highlighted, highlightedCode.length == (code as NSString).length {
                highlightedCode.enumerateAttributes(in: NSRange(location: 0, length: highlightedCode.length), options: []) { attrs, subRange, _ in
                    let targetRange = NSRange(location: codeRange.location + subRange.location, length: subRange.length)
                    if let color = attrs[.foregroundColor] as? NSColor {
                         self.safeAddAttribute(.foregroundColor, value: color, range: targetRange)
                    }
                }
            }

            let headerLen = codeRange.location - matchRange.location
            let headerRange = NSRange(location: matchRange.location, length: headerLen)
            let footerStart = codeRange.location + codeRange.length
            let footerLen = matchRange.location + matchRange.length - footerStart
            let footerRange = NSRange(location: footerStart, length: footerLen)

            safeAddAttribute(.foregroundColor, value: self.markupColor, range: headerRange)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: footerRange)
            safeAddAttribute(.backgroundColor, value: self.codeBackground, range: matchRange)
            let monoFont = NSFont.monospacedSystemFont(ofSize: self.baseFont.pointSize * 0.9, weight: .regular)
            safeAddAttribute(.font, value: monoFont, range: codeRange)
        }
    }
}
