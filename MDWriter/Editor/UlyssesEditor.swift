//
//  UlyssesEditor.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

struct UlyssesEditor: NSViewRepresentable {

    // MARK: - 绑定与属性

    @Binding var text: String
    var noteID: PersistentIdentifier?  // 用于识别是否切换了文档
    var configuration: EditorConfiguration
    @ObservedObject var controller: EditorController  // 外部控制（插入文本等）
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    // MARK: - 协调器 (Coordinator)

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: UlyssesEditor
        var isUpdatingFromSwiftUI = false

        init(_ parent: UlyssesEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // 避免循环更新：只有当内容确实发生变化时才更新 Binding
            if !isUpdatingFromSwiftUI && textView.string != parent.text {
                parent.text = textView.string
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            // 这里可以处理额外的选区逻辑，UlyssesTextView 内部已经处理了打字机滚动
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - NSView 生命周期

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.automaticallyAdjustsContentInsets = false  // 手动控制内边距

        // 设置文本存储堆栈 (Text Storage Stack)
        let textStorage = MarkdownTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            size: NSSize(width: configuration.contentWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = false  // 我们手动在 TextView 中控制 inset 和居中
        textContainer.lineFragmentPadding = 5
        layoutManager.addTextContainer(textContainer)

        // 设置 TextView
        let textView = UlyssesTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // 视觉初始配置
        textView.backgroundColor = .clear

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? UlyssesTextView,
            let textStorage = textView.textStorage as? MarkdownTextStorage
        else { return }

        context.coordinator.parent = self

        // 1. 处理外部命令 (插入文本)
        // 重新绑定闭包，因为 controller 可能没变，但 view 重写渲染了
        controller.insertTextAction = { [weak textView] (textToInsert: String) in
            guard let tv = textView else { return }
            tv.insertText(textToInsert, replacementRange: tv.selectedRange())
            tv.scrollRangeToVisible(tv.selectedRange())
        }

        controller.wrapSelectionAction = { [weak textView] (prefix: String, suffix: String) in
            guard let tv = textView else { return }
            tv.toggleWrap(prefix: prefix, suffix: suffix)
        }

        controller.getSelectedTextAction = { [weak textView] in
            guard let tv = textView else { return nil }
            let range = tv.selectedRange()
            guard range.length > 0 else { return nil }
            return (tv.string as NSString).substring(with: range)
        }

        // 2. 更新排版配置
        updateConfiguration(textView: textView, storage: textStorage)

        // 3. 更新文本内容
        // 利用 currentNoteIDHash 检查文档是否切换
        let newHash = noteID?.hashValue ?? 0
        let isNewDocument = textView.currentNoteIDHash != newHash

        if isNewDocument {
            textView.currentNoteIDHash = newHash
            textView.undoManager?.removeAllActions()  // 关键：切换文档时清除撤销栈
        }

        if textView.string != text || isNewDocument {
            context.coordinator.isUpdatingFromSwiftUI = true

            // 替换文本内容
            // 如果是全新文档，执行全量替换以避免渲染瑕疵
            textStorage.replaceCharacters(
                in: NSRange(location: 0, length: textStorage.length), with: text)

            // 恢复或重置选区状态
            if isNewDocument {
                textView.scroll(NSPoint.zero)  // 滚回顶部
                textView.setSelectedRange(NSRange(location: 0, length: 0))
            } else {
                let currentSelection = textView.selectedRange()
                if NSMaxRange(currentSelection) <= textStorage.length {
                    textView.setSelectedRange(currentSelection)
                }
            }

            context.coordinator.isUpdatingFromSwiftUI = false
        }

        // 4. 强制刷新高亮 (检测主题变化)
        if textStorage.theme != appTheme {
            textStorage.theme = appTheme
            textStorage.forceHighlight()
            textView.needsDisplay = true
        }
    }

    private func updateConfiguration(textView: UlyssesTextView, storage: MarkdownTextStorage) {
        // 更新 TextView 属性
        if textView.contentWidth != configuration.contentWidth {
            textView.contentWidth = configuration.contentWidth
        }
        textView.isTypewriterModeEnabled = configuration.typewriterMode

        // 更新 Storage 属性
        var storageChanged = false
        if storage.baseFont != configuration.nsFont {
            storage.baseFont = configuration.nsFont
            storageChanged = true
        }
        if storage.lineHeightMultiple != configuration.lineHeightMultiple {
            storage.lineHeightMultiple = configuration.lineHeightMultiple
            storageChanged = true
        }
        if storage.paragraphSpacing != configuration.paragraphSpacing {
            storage.paragraphSpacing = configuration.paragraphSpacing
            storageChanged = true
        }

        if storageChanged {
            storage.forceHighlight()
        }
    }
}