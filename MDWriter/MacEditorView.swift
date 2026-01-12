//
//  MacEditorView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import AppKit
import Combine
import SwiftUI

// 控制器，用于从外部向 Editor 发送指令
class EditorController: ObservableObject {
    var insertTextAction: ((String) -> Void)?

    func insert(_ text: String) {
        insertTextAction?(text)
    }
}

struct MacEditorView: NSViewControllerRepresentable {
    @Binding var text: String
    // 修改：只接收纯数据的配置结构体
    var configuration: TypographyConfiguration
    @ObservedObject var controller: EditorController
    @Environment(\.colorScheme) var colorScheme

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorView
        var isUpdatingFromSwiftUI = false

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdatingFromSwiftUI else { return }
            self.parent.text = textView.string
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSViewController(context: Context) -> NSViewController {
        let viewController = EditorViewController()
        viewController.coordinator = context.coordinator
        return viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        guard let vc = nsViewController as? EditorViewController else { return }

        context.coordinator.parent.controller.insertTextAction = { [weak vc] text in
            vc?.insertTextAtCursor(text)
        }

        // 更新排版属性，传入配置结构体
        vc.updateTypography(config: configuration)

        if vc.textView.string != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            vc.textView.string = text
            context.coordinator.isUpdatingFromSwiftUI = false
        }
    }
}

class EditorViewController: NSViewController, NSTextViewDelegate {
    var textView: NSTextView!
    var coordinator: MacEditorView.Coordinator?

    // 缓存当前的宽度设置，用于计算 Insets
    private var currentContentWidth: CGFloat = 700.0

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // 创建 Text Storage 体系
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = false
        textContainer.containerSize = NSSize(
            width: currentContentWidth, height: CGFloat.greatestFiniteMagnitude)
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        textView = CenteredTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = coordinator
        textView.autoresizingMask = [.width, .height]

        if let centeredTextView = textView as? CenteredTextView {
            centeredTextView.appearanceChanged = { [weak self] in
                if let config = self?.coordinator?.parent.configuration {
                    self?.updateTypography(config: config)
                }
            }
        }

        // 关键样式设置
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        // 光标颜色
        textView.insertionPointColor = .systemBlue
        textView.allowsUndo = true

        // 启用查找栏
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        scrollView.documentView = textView

        // 监听窗口大小变化以调整 Insets
        NotificationCenter.default.addObserver(
            self, selector: #selector(adjustInsets), name: NSView.frameDidChangeNotification,
            object: scrollView)

        // 监听格式化命令
        setupFormatNotifications()

        self.view = scrollView
    }

    private func setupFormatNotifications() {
        let nc = NotificationCenter.default

        // Find & Replace
        nc.addObserver(self, selector: #selector(handleShowFind), name: .showFind, object: nil)
        nc.addObserver(
            self, selector: #selector(handleShowFindReplace), name: .showFindReplace, object: nil)
        nc.addObserver(self, selector: #selector(handleFindNext), name: .findNext, object: nil)
        nc.addObserver(
            self, selector: #selector(handleFindPrevious), name: .findPrevious, object: nil)

        // Headings
        nc.addObserver(
            self, selector: #selector(handleHeading(_:)), name: .formatHeading, object: nil)

        // Text Styling
        nc.addObserver(self, selector: #selector(handleBold), name: .formatBold, object: nil)
        nc.addObserver(self, selector: #selector(handleItalic), name: .formatItalic, object: nil)
        nc.addObserver(
            self, selector: #selector(handleStrikethrough), name: .formatStrikethrough, object: nil)
        nc.addObserver(
            self, selector: #selector(handleHighlight), name: .formatHighlight, object: nil)

        // Lists
        nc.addObserver(
            self, selector: #selector(handleBulletList), name: .formatBulletList, object: nil)
        nc.addObserver(
            self, selector: #selector(handleNumberedList), name: .formatNumberedList, object: nil)
        nc.addObserver(
            self, selector: #selector(handleTaskList), name: .formatTaskList, object: nil)

        // Blocks
        nc.addObserver(
            self, selector: #selector(handleBlockquote), name: .formatBlockquote, object: nil)
        nc.addObserver(
            self, selector: #selector(handleCodeBlock), name: .formatCodeBlock, object: nil)
        nc.addObserver(
            self, selector: #selector(handleInlineCode), name: .formatInlineCode, object: nil)

        // Insert
        nc.addObserver(self, selector: #selector(handleInsertLink), name: .insertLink, object: nil)
        nc.addObserver(
            self, selector: #selector(handleInsertImage), name: .insertImage, object: nil)
        nc.addObserver(
            self, selector: #selector(handleHorizontalRule), name: .insertHorizontalRule,
            object: nil)
    }

    // MARK: - Find Handlers

    @objc private func handleShowFind() {
        // Tag 1: Show Find Panel
        performFindAction(tag: Int(NSFindPanelAction.showFindPanel.rawValue))
    }

    @objc private func handleShowFindReplace() {
        // For standard NSTextView, showing find panel is the main entry.
        // Users can switch to Replace in the panel.
        handleShowFind()
    }

    @objc private func handleFindNext() {
        performFindAction(tag: Int(NSFindPanelAction.next.rawValue))
    }

    @objc private func handleFindPrevious() {
        performFindAction(tag: Int(NSFindPanelAction.previous.rawValue))
    }

    private func performFindAction(tag: Int) {
        let menuItem = NSMenuItem()
        menuItem.tag = tag
        textView.performFindPanelAction(menuItem)
    }

    // MARK: - Format Handlers

    @objc private func handleHeading(_ notification: Notification) {
        guard let level = notification.object as? Int else { return }
        let prefix = String(repeating: "#", count: level) + " "
        insertAtLineStart(prefix)
    }

    @objc private func handleBold() { wrapSelection(with: "**") }
    @objc private func handleItalic() { wrapSelection(with: "*") }
    @objc private func handleStrikethrough() { wrapSelection(with: "~~") }
    @objc private func handleHighlight() { wrapSelection(with: "==") }

    @objc private func handleBulletList() { insertAtLineStart("- ") }
    @objc private func handleNumberedList() { insertAtLineStart("1. ") }
    @objc private func handleTaskList() { insertAtLineStart("- [ ] ") }

    @objc private func handleBlockquote() { insertAtLineStart("> ") }

    @objc private func handleCodeBlock() {
        insertTextAtCursor("\n```\n\n```\n")
    }

    @objc private func handleInlineCode() { wrapSelection(with: "`") }

    @objc private func handleInsertLink() {
        wrapSelection(prefix: "[", suffix: "](url)")
    }

    @objc private func handleInsertImage() {
        insertTextAtCursor("![alt text](image_url)")
    }

    @objc private func handleHorizontalRule() {
        insertTextAtCursor("\n---\n")
    }

    // MARK: - Helper Methods

    private func wrapSelection(with wrapper: String) {
        wrapSelection(prefix: wrapper, suffix: wrapper)
    }

    private func wrapSelection(prefix: String, suffix: String) {
        guard let range = textView.selectedRanges.first?.rangeValue else { return }
        let selectedText = (textView.string as NSString).substring(with: range)
        let newText = "\(prefix)\(selectedText)\(suffix)"
        textView.insertText(newText, replacementRange: range)
    }

    private func insertAtLineStart(_ prefix: String) {
        guard let range = textView.selectedRanges.first?.rangeValue else { return }
        let string = textView.string as NSString
        let lineRange = string.lineRange(for: range)

        // 检查是否已有相同前缀
        let lineStart = lineRange.location
        let existingLine = string.substring(with: lineRange)

        if existingLine.hasPrefix(prefix) {
            // 移除前缀
            let newLine = String(existingLine.dropFirst(prefix.count))
            textView.insertText(newLine, replacementRange: lineRange)
        } else {
            // 添加前缀
            textView.insertText(prefix, replacementRange: NSRange(location: lineStart, length: 0))
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        adjustInsets()
    }

    @objc func adjustInsets() {
        guard let scrollView = view as? NSScrollView else { return }
        let availableWidth = scrollView.bounds.width
        let padding = max(20, (availableWidth - currentContentWidth) / 2)  // 最小 20 padding

        textView.textContainerInset = NSSize(width: padding, height: 40)  // 固定的垂直 Padding
        textView.textContainer?.containerSize = NSSize(
            width: currentContentWidth, height: CGFloat.greatestFiniteMagnitude)
    }

    func updateTypography(config: TypographyConfiguration) {
        // 更新宽度
        if self.currentContentWidth != config.contentWidth {
            self.currentContentWidth = config.contentWidth
            adjustInsets()
            // 强制刷新布局
            textView.needsLayout = true
        }

        let font = config.nsFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = config.lineHeightMultiple
        paragraphStyle.paragraphSpacing = config.paragraphSpacing
        paragraphStyle.firstLineHeadIndent = config.firstLineIndent

        // 应用到默认样式
        textView.defaultParagraphStyle = paragraphStyle
        textView.font = font

        // 确保颜色适配深色/浅色模式
        let textColor = NSColor.labelColor
        textView.textColor = textColor

        // 设置 typingAttributes，保证新输入的文字遵循这些样式
        textView.typingAttributes = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor,
        ]

        // 注意：如果要实时更新**已存在**的文本样式，我们需要重置整个 storage 的属性
        if textView.textStorage?.length ?? 0 > 0 {
            textView.textStorage?.setAttributes(
                [
                    .font: font,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: textColor,
                ], range: NSRange(location: 0, length: textView.textStorage!.length))
        }
    }

    func insertTextAtCursor(_ text: String) {
        let range = textView.selectedRange()
        if range.location != NSNotFound {
            textView.insertText(text, replacementRange: range)
        } else {
            let endRange = NSRange(location: textView.string.count, length: 0)
            textView.insertText(text, replacementRange: endRange)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// 一个小的辅助类，确保点击空白处也能聚焦编辑器
class CenteredTextView: NSTextView {
    var appearanceChanged: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point) ?? self
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        appearanceChanged?()
    }
}
