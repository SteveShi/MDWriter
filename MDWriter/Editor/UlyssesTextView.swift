//
//  UlyssesTextView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import AppKit

class UlyssesTextView: NSTextView {

    // MARK: - Properties

    var currentNoteIDHash: Int = 0

    var contentWidth: CGFloat = 700 {
        didSet {
            if oldValue != contentWidth {
                updateLayout()
            }
        }
    }

    var isTypewriterModeEnabled: Bool = false

    // MARK: - Init

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        self.isRichText = false
        self.allowsUndo = true
        self.usesFindBar = true
        self.isIncrementalSearchingEnabled = true
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticTextReplacementEnabled = false

        // 视觉微调
        self.drawsBackground = false  // 我们自己画背景（如果需要）或者让 ScrollView 画
        self.insertionPointColor = .systemBlue

        // 监听 Frame 变化以调整居中
        self.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(frameDidChange), name: NSView.frameDidChangeNotification,
            object: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout & Centering

    @objc private func frameDidChange(_ notification: Notification) {
        updateLayout()
    }

    func updateLayout() {
        guard let container = self.textContainer else { return }

        // 动态计算 Padding 以前端居中
        let visibleWidth = self.visibleRect.width
        let padding = max(20, (visibleWidth - contentWidth) / 2)

        // 只有当 inset 真的改变时才设置，避免不必要的重绘循环
        if self.textContainerInset.width != padding {
            self.textContainerInset = NSSize(width: padding, height: 40)  // 顶部留白 40
        }

        // 确保容器宽度固定
        if container.containerSize.width != contentWidth {
            container.containerSize = NSSize(
                width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = false  // 关键：不随 View 宽度变化，而是我们手动控制 Inset
        }
    }

    // MARK: - Typewriter Mode

    func scrollToCenter() {
        guard isTypewriterModeEnabled,
            let scrollView = self.enclosingScrollView,
            let layoutManager = self.layoutManager,
            let textContainer = self.textContainer
        else { return }

        let selectedRange = self.selectedRange()
        if selectedRange.location == NSNotFound { return }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: selectedRange, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let viewHeight = scrollView.contentView.bounds.height
        // 目标 Y：让光标位置 (rect.origin.y) 位于视口中间
        let targetY = rect.origin.y - (viewHeight / 2) + (rect.height / 2)

        // 平滑滚动
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: max(0, targetY)))
        }
    }

    // 每次选区改变时，如果开启了打字机模式，尝试滚动
    override func setSelectedRange(
        _ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool
    ) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        if !stillSelecting {
            scrollToCenter()
        }
    }

    // MARK: - Keyboard Shortcuts for Formatting

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        switch key {
        case "b":  // ⌘B: Bold
            toggleWrap(prefix: "**", suffix: "**")
            return true
        case "i":  // ⌘I: Italic
            toggleWrap(prefix: "*", suffix: "*")
            return true
        case "k":  // ⌘K: Link
            insertLink()
            return true
        case "u":  // ⌘U: Strikethrough (Ulysses uses ⌘U for this)
            toggleWrap(prefix: "~~", suffix: "~~")
            return true
        case "`":  // ⌘`: Inline Code
            toggleWrap(prefix: "`", suffix: "`")
            return true
        case "\\":  // ⌘\: Increase Heading Level
            if event.modifierFlags.contains(.shift) {
                decreaseHeadingLevel()
            } else {
                increaseHeadingLevel()
            }
            return true
        default:
            break
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Formatting Helpers

    func toggleWrap(prefix: String, suffix: String) {
        let currentRange = selectedRange()
        guard currentRange.location != NSNotFound else { return }

        let text = (string as NSString)

        if currentRange.length == 0 {
            // No selection: insert prefix+suffix and place cursor in middle
            let insertion = prefix + suffix
            insertText(insertion, replacementRange: currentRange)
            setSelectedRange(
                NSRange(location: currentRange.location + prefix.utf16.count, length: 0))
        } else {
            // Has selection: check if already wrapped
            let selectedText = text.substring(with: currentRange)

            let prefixLength = prefix.utf16.count
            let suffixLength = suffix.utf16.count

            // Check if the selected text is already wrapped
            if selectedText.hasPrefix(prefix) && selectedText.hasSuffix(suffix)
                && selectedText.count >= prefixLength + suffixLength
            {
                // Unwrap
                let innerText = String(selectedText.dropFirst(prefixLength).dropLast(suffixLength))
                insertText(innerText, replacementRange: currentRange)
                setSelectedRange(
                    NSRange(location: currentRange.location, length: innerText.utf16.count))
            } else {
                // Wrap
                let wrapped = prefix + selectedText + suffix
                insertText(wrapped, replacementRange: currentRange)
                setSelectedRange(
                    NSRange(
                        location: currentRange.location + prefixLength,
                        length: selectedText.utf16.count))
            }
        }
    }

    private func insertLink() {
        let currentRange = selectedRange()
        guard currentRange.location != NSNotFound else { return }

        let text = (string as NSString)

        if currentRange.length == 0 {
            // No selection: insert placeholder
            let insertion = "[text](url)"
            insertText(insertion, replacementRange: currentRange)
            // Select "text" part
            setSelectedRange(NSRange(location: currentRange.location + 1, length: 4))
        } else {
            // Has selection: use it as the link text
            let selectedText = text.substring(with: currentRange)
            let insertion = "[\(selectedText)](url)"
            insertText(insertion, replacementRange: currentRange)
            // Select "url" part
            let urlStart = currentRange.location + 1 + selectedText.utf16.count + 2
            setSelectedRange(NSRange(location: urlStart, length: 3))
        }
    }

    private func increaseHeadingLevel() {
        let currentRange = selectedRange()
        let text = (string as NSString)
        let lineRange = text.lineRange(for: currentRange)
        let lineString = text.substring(with: lineRange)

        // Count existing #
        var hashCount = 0
        for char in lineString {
            if char == "#" { hashCount += 1 } else { break }
        }

        if hashCount < 6 {
            // Insert a # at the beginning of the line
            let insertLocation = lineRange.location
            insertText("#", replacementRange: NSRange(location: insertLocation, length: 0))

            // Add space if needed (if there was no space after #)
            if hashCount == 0 && !lineString.hasPrefix(" ") {
                insertText(" ", replacementRange: NSRange(location: insertLocation + 1, length: 0))
            }
        }
    }

    private func decreaseHeadingLevel() {
        let currentRange = selectedRange()
        let text = (string as NSString)
        let lineRange = text.lineRange(for: currentRange)
        let lineString = text.substring(with: lineRange)

        // Count existing #
        var hashCount = 0
        for char in lineString {
            if char == "#" { hashCount += 1 } else { break }
        }

        if hashCount > 0 {
            // Remove one # from the beginning
            let removeRange = NSRange(location: lineRange.location, length: 1)
            insertText("", replacementRange: removeRange)

            // If now no hashes and there's a lingering space, remove it too
            if hashCount == 1 {
                let newLineRange = text.lineRange(
                    for: NSRange(location: lineRange.location, length: 0))
                let newLineString = text.substring(with: newLineRange)
                if newLineString.hasPrefix(" ") {
                    insertText(
                        "", replacementRange: NSRange(location: lineRange.location, length: 1))
                }
            }
        }
    }
}
