//
//  MDEditorView.swift
//  MDEditor
//

import AppKit
import Combine
import SwiftUI

/// MDEditor 模块的公开视图
/// 使用 TextKit 2 实现 Ulysses 风格的所见即所得编辑
public struct MDEditorView: NSViewRepresentable {

    // MARK: - Properties

    @Binding var text: String
    var configuration: EditorConfiguration
    @ObservedObject var proxy: MDEditorProxy
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Initializer

    public init(text: Binding<String>, configuration: EditorConfiguration, proxy: MDEditorProxy) {
        self._text = text
        self.configuration = configuration
        self.proxy = proxy
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MDEditorView
        var isUpdatingFromSwiftUI = false
        weak var textView: MarkdownTextView?

        init(_ parent: MDEditorView) {
            self.parent = parent
            super.init()
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? MarkdownTextView else { return }

            if !isUpdatingFromSwiftUI && textView.string != parent.text {
                parent.text = textView.string
            }
        }

        // MARK: - Proxy Sync

        func setupProxyActions() {
            guard let textView = textView else { return }

            parent.proxy.insertTextAction = { [weak textView] text in
                guard let tv = textView else { return }
                let range = tv.selectedRange()
                tv.insertText(text, replacementRange: range)
            }

            parent.proxy.wrapSelectionAction = { [weak textView] prefix, suffix in
                guard let tv = textView else { return }
                let range = tv.selectedRange()
                let selectedText = (tv.string as NSString).substring(with: range)
                let newText = "\(prefix)\(selectedText)\(suffix)"
                tv.insertText(newText, replacementRange: range)
            }

            parent.proxy.getSelectedTextAction = { [weak textView] in
                guard let tv = textView else { return nil }
                let range = tv.selectedRange()
                return (tv.string as NSString).substring(with: range)
            }

            parent.proxy.findNextAction = { [weak textView] searchText in
                guard let tv = textView, !searchText.isEmpty else { return }
                let text = tv.string as NSString
                let currentLocation = tv.selectedRange().location + tv.selectedRange().length
                let searchRange = NSRange(
                    location: currentLocation, length: text.length - currentLocation)

                var foundRange = text.range(
                    of: searchText, options: .caseInsensitive, range: searchRange)
                if foundRange.location == NSNotFound {
                    foundRange = text.range(of: searchText, options: .caseInsensitive)
                }

                if foundRange.location != NSNotFound {
                    tv.setSelectedRange(foundRange)
                    tv.scrollRangeToVisible(foundRange)
                }
            }

            parent.proxy.findPreviousAction = { [weak textView] searchText in
                guard let tv = textView, !searchText.isEmpty else { return }
                let text = tv.string as NSString
                let currentLocation = tv.selectedRange().location
                let searchRange = NSRange(location: 0, length: currentLocation)

                var foundRange = text.range(
                    of: searchText, options: [.caseInsensitive, .backwards], range: searchRange)
                if foundRange.location == NSNotFound {
                    foundRange = text.range(
                        of: searchText, options: [.caseInsensitive, .backwards])
                }

                if foundRange.location != NSNotFound {
                    tv.setSelectedRange(foundRange)
                    tv.scrollRangeToVisible(foundRange)
                }
            }

            parent.proxy.replaceAction = { [weak textView] searchText, replaceText in
                guard let tv = textView else { return }
                let range = tv.selectedRange()
                let selectedText = (tv.string as NSString).substring(with: range)
                if selectedText.lowercased() == searchText.lowercased() {
                    tv.insertText(replaceText, replacementRange: range)
                }
            }

            parent.proxy.replaceAllAction = { [weak textView] searchText, replaceText in
                guard let tv = textView, !searchText.isEmpty else { return }
                let newString = tv.string.replacingOccurrences(
                    of: searchText, with: replaceText, options: .caseInsensitive)
                tv.string = newString
                tv.highlightMarkdown()
            }

            parent.proxy.printAction = { [weak textView] in
                textView?.printView(nil)
            }

            parent.proxy.setHighlighterDarkThemeAction = { [weak textView] isDark in
                textView?.updateTheme(isDark: isDark)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - NSView Lifecycle

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        let textView = MarkdownTextView(frame: .zero)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(
            width: configuration.horizontalPadding, height: configuration.verticalPadding)

        textView.isRichText = false
        textView.allowsUndo = true
        textView.backgroundColor = .clear

        scrollView.documentView = textView
        textView.string = text
        textView.highlightMarkdown()

        context.coordinator.setupProxyActions()

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? MarkdownTextView else { return }

        let isDark = colorScheme == .dark
        textView.updateTheme(isDark: isDark)

        if !context.coordinator.isUpdatingFromSwiftUI && textView.string != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            textView.string = text
            textView.highlightMarkdown()
            context.coordinator.isUpdatingFromSwiftUI = false
        }
    }
}

// MARK: - MarkdownTextView

class MarkdownTextView: NSTextView {
    private lazy var highlighter = MarkdownHighlighter()
    private var isComposing = false

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        isComposing = true
        super.setMarkedText(
            string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    override func unmarkText() {
        isComposing = false
        super.unmarkText()
        highlightMarkdown()
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        if !isComposing {
            highlightMarkdown(in: rangeForUserTextChange)
        }
    }

    override func didChangeText() {
        super.didChangeText()
        if !isComposing {
            highlightMarkdown(in: rangeForUserTextChange)
        }
    }

    func highlightMarkdown() {
        guard let textStorage = textStorage else { return }
        highlightMarkdown(in: NSRange(location: 0, length: textStorage.length))
    }

    func highlightMarkdown(in range: NSRange) {
        guard let textStorage = textStorage, !isComposing else { return }

        // 扩展到完整行范围以优化高亮渲染
        let text = textStorage.string as NSString
        let lineRange = text.lineRange(for: range)

        highlighter.highlight(textStorage, in: lineRange)
    }

    func updateTheme(isDark: Bool) {
        highlighter.isDarkTheme = isDark
        backgroundColor = .clear
        insertionPointColor = isDark ? .white : .black
        highlightMarkdown()
    }
}
