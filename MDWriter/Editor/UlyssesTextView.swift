//
//  UlyssesTextView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

#if os(macOS)
import AppKit

class UlyssesTextView: NSTextView {

    // MARK: - 属性

    var currentNoteIDHash: Int = 0

    var contentWidth: CGFloat = 700 {
        didSet {
            if oldValue != contentWidth {
                updateLayout()
            }
        }
    }

    var isTypewriterModeEnabled: Bool = false

    // MARK: - 初始化

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
        self.drawsBackground = false  // 我们自己绘制背景（如果需要）或者让 ScrollView 绘制
        self.insertionPointColor = .systemBlue

        // 监听 Frame 变化以调整内容居中
        self.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(frameDidChange), name: NSView.frameDidChangeNotification,
            object: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 布局与居中

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
            container.widthTracksTextView = false  // 关键：不随 View 宽度变化，而是手动控制 Inset
        }
    }

    // MARK: - 打字机模式

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

    // 每次选区改变时，如果开启了打字机模式，尝试滚动到中心
    override func setSelectedRange(
        _ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool
    ) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        if !stillSelecting {
            scrollToCenter()
        }
    }

    // MARK: - 快捷键处理

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        switch key {
        case "b":  // ⌘B: 加粗
            toggleWrap(prefix: "**", suffix: "**")
            return true
        case "i":  // ⌘I: 斜体
            toggleWrap(prefix: "*", suffix: "*")
            return true
        case "k":  // ⌘K: 插入链接
            insertLink()
            return true
        case "u":  // ⌘U: 删除线
            toggleWrap(prefix: "~~", suffix: "~~")
            return true
        case "`":  // ⌘`: 行内代码
            toggleWrap(prefix: "`", suffix: "`")
            return true
        case "\\":  // ⌘\: 调整标题级别
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

    // MARK: - 格式化辅助方法

    func toggleWrap(prefix: String, suffix: String) {
        let currentRange = selectedRange()
        guard currentRange.location != NSNotFound else { return }

        let text = (string as NSString)

        if currentRange.length == 0 {
            // 无选区：插入前后缀并将光标置于中间
            let insertion = prefix + suffix
            insertText(insertion, replacementRange: currentRange)
            setSelectedRange(
                NSRange(location: currentRange.location + prefix.utf16.count, length: 0))
        } else {
            // 有选区：检查是否已被包裹
            let selectedText = text.substring(with: currentRange)

            let prefixLength = prefix.utf16.count
            let suffixLength = suffix.utf16.count

            // 检查选中的文本是否已被指定的前后缀包裹
            if selectedText.hasPrefix(prefix) && selectedText.hasSuffix(suffix)
                && selectedText.count >= prefixLength + suffixLength
            {
                // 解除包裹
                let innerText = String(selectedText.dropFirst(prefixLength).dropLast(suffixLength))
                insertText(innerText, replacementRange: currentRange)
                setSelectedRange(
                    NSRange(location: currentRange.location, length: innerText.utf16.count))
            } else {
                // 应用包裹
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
            // 无选区：插入占位符
            let insertion = "[text](url)"
            insertText(insertion, replacementRange: currentRange)
            // 选中 "text" 部分以便快速修改
            setSelectedRange(NSRange(location: currentRange.location + 1, length: 4))
        } else {
            // 有选区：使用选中内容作为链接文字
            let selectedText = text.substring(with: currentRange)
            let insertion = "[\(selectedText)](url)"
            insertText(insertion, replacementRange: currentRange)
            // 选中 "url" 部分以便快速修改
            let urlStart = currentRange.location + 1 + selectedText.utf16.count + 2
            setSelectedRange(NSRange(location: urlStart, length: 3))
        }
    }

    private func increaseHeadingLevel() {
        let currentRange = selectedRange()
        let text = (string as NSString)
        let lineRange = text.lineRange(for: currentRange)
        let lineString = text.substring(with: lineRange)

        // 统计现有的 # 数量
        var hashCount = 0
        for char in lineString {
            if char == "#" { hashCount += 1 } else { break }
        }

        if hashCount < 6 {
            // 在行首插入一个 #
            let insertLocation = lineRange.location
            insertText("#", replacementRange: NSRange(location: insertLocation, length: 0))

            // 如果原本没有 # 且插入后紧跟文字（无空格），则补一个空格
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

        // 统计现有的 # 数量
        var hashCount = 0
        for char in lineString {
            if char == "#" { hashCount += 1 } else { break }
        }

        if hashCount > 0 {
            // 从行首移除一个 #
            let removeRange = NSRange(location: lineRange.location, length: 1)
            insertText("", replacementRange: removeRange)

            // 如果原本只有一个 #，且后面跟着空格，则连空格一起移除
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
}#endif
