//
//  MarkdownTextStorage.swift
//  简化版 Markdown 渲染 - 使用正则表达式和 Highlightr
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
@preconcurrency import Highlightr

nonisolated class MarkdownTextStorage: NSTextStorage {

    nonisolated(unsafe) private let backingStore = NSMutableAttributedString()
    nonisolated(unsafe) private let highlightr = Highlightr()!
    nonisolated(unsafe) private var currentHighlightrThemeName: String?

    nonisolated(unsafe) var theme: AppTheme = .light
    nonisolated(unsafe) var baseFont: PlatformFont = PlatformFont.systemFont(ofSize: 17)
    
    private var syntaxFont: PlatformFont {
        PlatformFont.systemFont(ofSize: baseFont.pointSize * 0.9, weight: .light)
    }

    nonisolated(unsafe) var lineHeightMultiple: CGFloat = 1.7
    nonisolated(unsafe) var paragraphSpacing: CGFloat = 12.0

    nonisolated(unsafe) var isComposing: Bool = false
    nonisolated(unsafe) private var isHighlighting: Bool = false

    private enum Regex {
        static let bold = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#)
        static let italic = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#)
        static let inlineCode = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
        static let links = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
        static let strikethrough = try! NSRegularExpression(pattern: #"~~(.*?)~~"#)
        static let codeBlocks = try! NSRegularExpression(pattern: #"```([a-zA-Z0-9+\-]*)\n([\s\S]*?)```"#)
        static let blockquote = try! NSRegularExpression(pattern: #"^> (.*)"#, options: .anchorsMatchLines)
        static let listMarker = try! NSRegularExpression(pattern: #"^([\s]*)([\*\-\+]|[0-9]+\.)\s"#, options: .anchorsMatchLines)
    }
    
    private func applySyntaxStyle(to range: NSRange) {
        safeAddAttribute(.font, value: syntaxFont, range: range)
        safeAddAttribute(.foregroundColor, value: markupColor, range: range)
    }

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    #if os(macOS)
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        super.init(pasteboardPropertyList: propertyList, ofType: type)
    }
    #endif

    private var textColor: PlatformColor {
        theme == .light ? PlatformColor(white: 0.15, alpha: 1.0) : PlatformColor(white: 0.88, alpha: 1.0)
    }

    private var headingColor: PlatformColor {
        theme == .light ? PlatformColor.black : PlatformColor.white
    }

    private var markupColor: PlatformColor {
        theme == .light ? PlatformColor(white: 0.5, alpha: 1.0) : PlatformColor(white: 0.5, alpha: 1.0)
    }

    private var linkColor: PlatformColor {
        #if os(macOS)
        return NSColor.systemBlue
        #else
        return UIColor.systemBlue
        #endif
    }

    private var codeColor: PlatformColor {
        theme == .light
            ? PlatformColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
            : PlatformColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
    }

    private var codeBackground: PlatformColor {
        theme == .light ? PlatformColor(white: 0.95, alpha: 1.0) : PlatformColor(white: 0.15, alpha: 1.0)
    }

    private var blockquoteColor: PlatformColor {
        theme == .light ? PlatformColor(white: 0.4, alpha: 1.0) : PlatformColor(white: 0.6, alpha: 1.0)
    }
    
    private var blockquoteBackground: PlatformColor {
        theme == .light ? PlatformColor(white: 0.97, alpha: 1.0) : PlatformColor(white: 0.12, alpha: 1.0)
    }

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

    override func processEditing() {
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

    private func performHighlighting(editedRange: NSRange?) {
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

    private func safeAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        if NSMaxRange(range) <= length {
            backingStore.addAttribute(name, value: value, range: range)
        }
    }

    private func styleLineStructure(in lineRange: NSRange, text: NSString) {
        let lineString = text.substring(with: lineRange)
        if lineString.hasPrefix("#") { styleHeading(in: lineRange, lineString: lineString); return }
        if lineString.hasPrefix("> ") { styleBlockquote(in: lineRange, lineString: lineString); return }
        let listRegex = Regex.listMarker
        if let match = listRegex.firstMatch(in: lineString, range: NSRange(location: 0, length: lineString.count)) {
            styleListItem(in: lineRange, lineString: lineString, match: match)
            return
        }
    }

    private func styleHeading(in lineRange: NSRange, lineString: String) {
        var level = 0
        for char in lineString { if char == "#" { level += 1 } else { break } }
        guard level >= 1 && level <= 6 else { return }
        let afterHash = String(lineString.dropFirst(level))
        guard afterHash.hasPrefix(" ") || afterHash.isEmpty else { return }
        let contentStart = lineRange.location + level + (afterHash.hasPrefix(" ") ? 1 : 0)
        let contentLength = lineRange.length - (contentStart - lineRange.location)
        if contentLength > 0 {
            let contentRange = NSRange(location: contentStart, length: contentLength)
            let sizeMultiplier: CGFloat
            switch level {
                case 1: sizeMultiplier = 1.8; case 2: sizeMultiplier = 1.5; case 3: sizeMultiplier = 1.3; default: sizeMultiplier = 1.1
            }
            let fontSize = baseFont.pointSize * sizeMultiplier
            let headingFont = baseFont.bold.withSize(fontSize)
            safeAddAttribute(.font, value: headingFont, range: contentRange)
            safeAddAttribute(.foregroundColor, value: headingColor, range: contentRange)
        }
        let hashRange = NSRange(location: lineRange.location, length: level + (afterHash.hasPrefix(" ") ? 1 : 0))
        applySyntaxStyle(to: hashRange)
    }
    
    private func styleBlockquote(in lineRange: NSRange, lineString: String) {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.firstLineHeadIndent = 24
        style.headIndent = 24
        safeAddAttribute(.paragraphStyle, value: style, range: lineRange)
        safeAddAttribute(.foregroundColor, value: blockquoteColor, range: lineRange)
        safeAddAttribute(.backgroundColor, value: blockquoteBackground, range: lineRange)
        let markerRange = NSRange(location: lineRange.location, length: 2)
        if markerRange.location + markerRange.length <= length { applySyntaxStyle(to: markerRange) }
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
        let globalMarkerRange = NSRange(location: lineRange.location + markerRangeInLine.location, length: markerRangeInLine.length)
        applySyntaxStyle(to: globalMarkerRange)
    }

    private func styleBold(text: NSString, range: NSRange) {
        Regex.bold.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            safeAddAttribute(.font, value: self.baseFont.bold, range: contentRange)
            let openRange = NSRange(location: matchRange.location, length: 2)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            applySyntaxStyle(to: openRange); applySyntaxStyle(to: closeRange)
        }
    }

    private func styleItalic(text: NSString, range: NSRange) {
        Regex.italic.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            safeAddAttribute(.font, value: self.baseFont.italic, range: contentRange)
            let openRange = NSRange(location: matchRange.location, length: 1)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            applySyntaxStyle(to: openRange); applySyntaxStyle(to: closeRange)
        }
    }

    private func styleInlineCode(text: NSString, range: NSRange) {
        Regex.inlineCode.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            let monoFont = PlatformFont.monospacedSystemFont(ofSize: self.baseFont.pointSize * 0.95, weight: .regular)
            safeAddAttribute(.font, value: monoFont, range: contentRange)
            safeAddAttribute(.foregroundColor, value: self.codeColor, range: contentRange)
            safeAddAttribute(.backgroundColor, value: self.codeBackground, range: matchRange)
            let openRange = NSRange(location: matchRange.location, length: 1)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 1, length: 1)
            applySyntaxStyle(to: openRange); applySyntaxStyle(to: closeRange)
        }
    }

    private func styleLinks(text: NSString, range: NSRange) {
        Regex.links.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let textRange = match?.range(at: 1), let urlRange = match?.range(at: 2) else { return }
            safeAddAttribute(.foregroundColor, value: self.linkColor, range: textRange)
            safeAddAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            let bracketOpen = NSRange(location: matchRange.location, length: 1)
            let bracketClose = NSRange(location: textRange.location + textRange.length, length: 1)
            let parenOpen = NSRange(location: urlRange.location - 1, length: 1)
            let parenClose = NSRange(location: urlRange.location + urlRange.length, length: 1)
            [bracketOpen, bracketClose, parenOpen, parenClose].forEach { applySyntaxStyle(to: $0) }
            safeAddAttribute(.font, value: syntaxFont, range: urlRange)
            safeAddAttribute(.foregroundColor, value: self.markupColor.withAlphaComponent(0.4), range: urlRange)
        }
    }

    private func styleStrikethrough(text: NSString, range: NSRange) {
        Regex.strikethrough.enumerateMatches(in: text as String, range: range) { match, _, _ in
            guard let matchRange = match?.range, let contentRange = match?.range(at: 1) else { return }
            safeAddAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
            let openRange = NSRange(location: matchRange.location, length: 2)
            let closeRange = NSRange(location: matchRange.location + matchRange.length - 2, length: 2)
            applySyntaxStyle(to: openRange); applySyntaxStyle(to: closeRange)
        }
    }

    private let codeBlockCache = NSCache<NSString, NSAttributedString>()

    private func styleCodeBlocks(text: NSString, range: NSRange, changedRange: NSRange?) {
        let highlightr = self.highlightr
        let targetTheme = (self.theme == .dark) ? "monokai-sublime" : "xcode"
        if currentHighlightrThemeName != targetTheme {
            if highlightr.setTheme(to: targetTheme) { currentHighlightrThemeName = targetTheme; codeBlockCache.removeAllObjects() }
        }
        Regex.codeBlocks.enumerateMatches(in: text as String, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range, let langRange = match?.range(at: 1), let codeRange = match?.range(at: 2) else { return }
            let language = text.substring(with: langRange)
            let code = text.substring(with: codeRange)
            let cacheKey = "\(language):\(code)" as NSString
            var highlightedCode: NSAttributedString?
            if let cached = codeBlockCache.object(forKey: cacheKey) { highlightedCode = cached }
            else {
                let highlighted = language.isEmpty ? highlightr.highlight(code) : highlightr.highlight(code, as: language)
                if let validHighlight = highlighted, validHighlight.length == (code as NSString).length {
                    highlightedCode = validHighlight; codeBlockCache.setObject(validHighlight, forKey: cacheKey)
                }
            }
            if let highlightedCode = highlightedCode {
                highlightedCode.enumerateAttributes(in: NSRange(location: 0, length: highlightedCode.length), options: []) { attrs, subRange, _ in
                    let targetRange = NSRange(location: codeRange.location + subRange.location, length: subRange.length)
                    if let color = attrs[.foregroundColor] as? PlatformColor { self.safeAddAttribute(.foregroundColor, value: color, range: targetRange) }
                }
            }
            let headerRange = NSRange(location: matchRange.location, length: codeRange.location - matchRange.location)
            let footerStart = codeRange.location + codeRange.length
            let footerRange = NSRange(location: footerStart, length: matchRange.location + matchRange.length - footerStart)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: headerRange)
            safeAddAttribute(.foregroundColor, value: self.markupColor, range: footerRange)
            safeAddAttribute(.backgroundColor, value: self.codeBackground, range: matchRange)
            let monoFont = PlatformFont.monospacedSystemFont(ofSize: self.baseFont.pointSize * 0.9, weight: .regular)
            safeAddAttribute(.font, value: monoFont, range: codeRange)
        }
    }
}
