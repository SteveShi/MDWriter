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
nonisolated class MarkdownTextStorage: NSTextStorage {

    // MARK: - 属性 (nonisolated(unsafe) 允许在非隔离方法中访问)

    nonisolated(unsafe) private let backingStore = NSMutableAttributedString()
    // 强制解包，以防 Highlightr() 初始化失败
    nonisolated(unsafe) private let highlightr = Highlightr()!
    nonisolated(unsafe) private var currentHighlightrThemeName: String?

    nonisolated(unsafe) var theme: AppTheme = .light
    nonisolated(unsafe) var baseFont: NSFont = NSFont(name: "PingFang SC", size: 17) ?? .systemFont(ofSize: 17)
    
    // 统一的语法符号字体：固定大小和字重，仿 Ulysses 风格
    private var syntaxFont: NSFont {
        NSFont.systemFont(ofSize: baseFont.pointSize * 0.9, weight: .light)
    }

    nonisolated(unsafe) var lineHeightMultiple: CGFloat = 1.7
    nonisolated(unsafe) var paragraphSpacing: CGFloat = 12.0

    nonisolated(unsafe) var isComposing: Bool = false
    nonisolated(unsafe) private var isHighlighting: Bool = false

    // MARK: - 正则表达式缓存 (使用 Raw Strings 确保转义正确)

    private enum Regex {
        static let bold = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#)
        static let italic = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, options: [])
        static let inlineCode = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
        static let links = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, options: [])
        static let strikethrough = try! NSRegularExpression(pattern: #"~~(.+?)~~"#)
        static let codeBlocks = try! NSRegularExpression(pattern: #"```([a-zA-Z0-9+\-]*)\n([\s\S]*?)```"#)
        // 结构化行：引用块和列表
        static let blockquote = try! NSRegularExpression(pattern: #"^> (.*)"#, options: .anchorsMatchLines)
        static let listMarker = try! NSRegularExpression(pattern: #"^([\s]*)([\*\-\+]|[0-9]+\.)\s"#, options: .anchorsMatchLines)
    }
    
    // MARK: - 辅助方法：应用语法标记样式
    
    private func applySyntaxStyle(to range: NSRange) {
        safeAddAttribute(.font, value: syntaxFont, range: range)
        safeAddAttribute(.foregroundColor, value: markupColor, range: range)
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

    private var blockquoteColor: NSColor {
        theme == .light ? NSColor(white: 0.4, alpha: 1.0) : NSColor(white: 0.6, alpha: 1.0)
    }
    
    private var blockquoteBackground: NSColor {
        theme == .light ? NSColor(white: 0.97, alpha: 1.0) : NSColor(white: 0.12, alpha: 1.0)
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
        // 由于所有属性都是 nonisolated(unsafe)，且我们假设 processEditing 在主线程调用
        // 我们不需要显式的 assumeIsolated，直接执行逻辑。
        
        if editedMask.contains(.editedCharacters) && !isHighlighting && !isComposing {
            let range = editedRange
            performHighlighting(editedRange: range)
        }
        super.processEditing()
    }

    func forceHighlight() {
        if !isComposing {
            performHighlighting(editedRange: nil)
        }
    }

    // MARK: - 高亮处理

    private func performHighlighting(editedRange: NSRange?) {
        guard length > 0 else { return }
        isHighlighting = true

        let wholeRange = NSRange(location: 0, length: length)
        let text = string as NSString

        // 性能优化：
        // 为了保持一致性，我们总是清除并重新对整个文本应用基础属性，
        // 但我们可以优化应用繁重逻辑的地方。
        // 对于真正的“部分更新”，我们需要计算受影响的行范围，并且只清除/更新该部分。
        // 然而，Markdown 的正则匹配（如代码块）可能是多行的，因此如果没有强大的解析器，部分更新是有风险的。
        // 
        // 当前的折衷方案：
        // 1. 结构（标题、粗体等）通常足够快，可以对全文进行处理。
        // 2. 代码块 (Highlightr/JS) 非常慢。我们必须过滤这些操作。
        
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
            self.styleLineStructure(in: lineRange, text: text)
        }

        styleBold(text: text, range: wholeRange)
        styleItalic(text: text, range: wholeRange)
        styleInlineCode(text: text, range: wholeRange)
        styleLinks(text: text, range: wholeRange)
        styleStrikethrough(text: text, range: wholeRange)
        styleCodeBlocks(text: text, range: wholeRange, changedRange: editedRange)

        isHighlighting = false
    }

    // MARK: - 样式处理辅助方法 (添加了 Range 检查以防止崩溃)

    private func safeAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        if NSMaxRange(range) <= length {
            backingStore.addAttribute(name, value: value, range: range)
        }
    }

    private func styleLineStructure(in lineRange: NSRange, text: NSString) {
        let lineString = text.substring(with: lineRange)
        
        // 1. 处理标题
        if lineString.hasPrefix("#") {
            styleHeading(in: lineRange, lineString: lineString)
            return
        }
        
        // 2. 处理引用块 (Blockquote)
        if lineString.hasPrefix("> ") {
            styleBlockquote(in: lineRange, lineString: lineString)
            return
        }
        
        // 3. 处理列表项 (List Item)
        // 匹配 -, *, + 或 数字. 开头的行
        let listRegex = Regex.listMarker
        if let match = listRegex.firstMatch(in: lineString, range: NSRange(location: 0, length: lineString.count)) {
            styleListItem(in: lineRange, lineString: lineString, match: match)
            return
        }
    }

    private func styleHeading(in lineRange: NSRange, lineString: String) {
        var level = 0
        for char in lineString {
            if char == "#" { level += 1 } else { break }
        }
        guard level >= 1 && level <= 6 else { return }

        let afterHash = String(lineString.dropFirst(level))
        guard afterHash.hasPrefix(" ") || afterHash.isEmpty else { return }

        // 内容部分：应用大字号和粗体
        let contentStart = lineRange.location + level + (afterHash.hasPrefix(" ") ? 1 : 0)
        let contentLength = lineRange.length - (contentStart - lineRange.location)

        if contentLength > 0 {
            let contentRange = NSRange(location: contentStart, length: contentLength)
            let sizeMultiplier: CGFloat
            switch level {
            case 1: sizeMultiplier = 1.8
            case 2: sizeMultiplier = 1.5
            case 3: sizeMultiplier = 1.3
            default: sizeMultiplier = 1.1
            }
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

        // 标记部分（#）：应用统一的语法字体，不随标题等级变大
        let hashRange = NSRange(location: lineRange.location, length: level + (afterHash.hasPrefix(" ") ? 1 : 0))
        applySyntaxStyle(to: hashRange)

        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.3
        style.paragraphSpacingBefore = CGFloat(20 - level * 2)
        style.paragraphSpacing = 6
        safeAddAttribute(.paragraphStyle, value: style, range: lineRange)
    }
    
    private func styleBlockquote(in lineRange: NSRange, lineString: String) {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.firstLineHeadIndent = 24
        style.headIndent = 24
        
        safeAddAttribute(.paragraphStyle, value: style, range: lineRange)
        safeAddAttribute(.foregroundColor, value: blockquoteColor, range: lineRange)
        safeAddAttribute(.backgroundColor, value: blockquoteBackground, range: lineRange)
        
        // 引用标记 > ：统一语法样式
        let markerRange = NSRange(location: lineRange.location, length: 2)
        if markerRange.location + markerRange.length <= length {
            applySyntaxStyle(to: markerRange)
        }
    }
    
    private func styleListItem(in lineRange: NSRange, lineString: String, match: NSTextCheckingResult) {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        
        let indentRange = match.range(at: 1)
        let markerRangeInLine = match.range(at: 2)
        let indentLevel = indentRange.length
        
        let baseIndent: CGFloat = CGFloat(indentLevel * 8 + 20)
        style.firstLineHeadIndent = baseIndent
        style.headIndent = baseIndent + 18
        
        safeAddAttribute(.paragraphStyle, value: style, range: lineRange)
        
        // 列表标记 - * 1. ：统一语法样式
        let globalMarkerRange = NSRange(location: lineRange.location + markerRangeInLine.location, length: markerRangeInLine.length)
        applySyntaxStyle(to: globalMarkerRange)
    }

    private func styleBold(text: NSString, range: NSRange) {
        Regex.bold.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            
            // 内容：粗体
            let boldFont = NSFontManager.shared.convert(self.baseFont, toHaveTrait: .boldFontMask)
            safeAddAttribute(.font, value: boldFont, range: contentRange)
            
            // 符号 ** ：统一语法样式
            let openRange = NSRange(location: matchRange.location, length: 2)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            applySyntaxStyle(to: openRange)
            applySyntaxStyle(to: closeRange)
        }
    }

    private func styleItalic(text: NSString, range: NSRange) {
        Regex.italic.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            
            // 内容：斜体
            let italicFont = NSFontManager.shared.convert(self.baseFont, toHaveTrait: .italicFontMask)
            safeAddAttribute(.font, value: italicFont, range: contentRange)
            
            // 符号 * ：统一语法样式
            let openRange = NSRange(location: matchRange.location, length: 1)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            applySyntaxStyle(to: openRange)
            applySyntaxStyle(to: closeRange)
        }
    }

    private func styleInlineCode(text: NSString, range: NSRange) {
        Regex.inlineCode.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            
            // 内容：等宽字体
            let monoFont = NSFont.monospacedSystemFont(ofSize: self.baseFont.pointSize * 0.95, weight: .regular)
            safeAddAttribute(.font, value: monoFont, range: contentRange)
            safeAddAttribute(.foregroundColor, value: self.codeColor, range: contentRange)
            safeAddAttribute(.backgroundColor, value: self.codeBackground, range: matchRange)
            
            // 符号 ` ：统一语法样式
            let openRange = NSRange(location: matchRange.location, length: 1)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            applySyntaxStyle(to: openRange)
            applySyntaxStyle(to: closeRange)
        }
    }

    private func styleLinks(text: NSString, range: NSRange) {
        Regex.links.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let textRange = match?.range(at: 1), let urlRange = match?.range(at: 2) else { return }
            
            // 链接文字
            safeAddAttribute(.foregroundColor, value: self.linkColor, range: textRange)
            safeAddAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            
            // 链接符号 [ ] ( ) ：统一语法样式
            let bracketOpen = NSRange(location: matchRange.location, length: 1)
            let bracketClose = NSRange(location: textRange.location + textRange.length, length: 1)
            let parenOpen = NSRange(location: urlRange.location - 1, length: 1)
            let parenClose = NSRange(location: urlRange.location + urlRange.length, length: 1)
            
            [bracketOpen, bracketClose, parenOpen, parenClose].forEach { applySyntaxStyle(to: $0) }
            
            // URL 部分：更淡的颜色
            safeAddAttribute(.font, value: syntaxFont, range: urlRange)
            safeAddAttribute(.foregroundColor, value: self.markupColor.withAlphaComponent(0.4), range: urlRange)
        }
    }

    private func styleStrikethrough(text: NSString, range: NSRange) {
        Regex.strikethrough.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            
            safeAddAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
            
            // 符号 ~~ ：统一语法样式
            let openRange = NSRange(location: matchRange.location, length: 2)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            applySyntaxStyle(to: openRange)
            applySyntaxStyle(to: closeRange)
        }
    }

    // MARK: - Cache
    
    private let codeBlockCache = NSCache<NSString, NSAttributedString>()

    private func styleCodeBlocks(text: NSString, range: NSRange, changedRange: NSRange?) {
        let highlightr = self.highlightr
        let targetTheme = (self.theme == .dark) ? "monokai-sublime" : "xcode"
        if currentHighlightrThemeName != targetTheme {
            if highlightr.setTheme(to: targetTheme) {
                currentHighlightrThemeName = targetTheme
                codeBlockCache.removeAllObjects() // Clear cache on theme change
            }
        }

        Regex.codeBlocks.enumerateMatches(in: text as String, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range, let langRange = match?.range(at: 1), let codeRange = match?.range(at: 2) else { return }
            let language = text.substring(with: langRange)
            let code = text.substring(with: codeRange)
            
            let cacheKey = "\(language):\(code)" as NSString
            var highlightedCode: NSAttributedString?
            
            // 尝试先使用缓存
            if let cached = codeBlockCache.object(forKey: cacheKey) {
                highlightedCode = cached
            } else {
                // 如果不在缓存中，仅在必要时计算（或者当我们被迫重新渲染所有内容时）。
                // 由于我们清除了属性，如果未缓存，我们必须重新计算它。
                // 但缓存将在第二次遍历时节省时间。
                let highlighted = language.isEmpty ? highlightr.highlight(code) : highlightr.highlight(code, as: language)
                if let validHighlight = highlighted, validHighlight.length == (code as NSString).length {
                    highlightedCode = validHighlight
                    codeBlockCache.setObject(validHighlight, forKey: cacheKey)
                }
            }
            
            // 应用高亮代码的属性（来自缓存或新计算）
            if let highlightedCode = highlightedCode {
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
