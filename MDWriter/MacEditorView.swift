//
//  MacEditorView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import SwiftUI
import AppKit
import Combine

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
        textContainer.containerSize = NSSize(width: currentContentWidth, height: CGFloat.greatestFiniteMagnitude)
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        
        textView = CenteredTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = coordinator
        textView.autoresizingMask = [.width, .height]
        
        // 关键样式设置
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        // 光标颜色
        textView.insertionPointColor = .systemBlue
        textView.allowsUndo = true

        scrollView.documentView = textView
        
        // 监听窗口大小变化以调整 Insets
        NotificationCenter.default.addObserver(self, selector: #selector(adjustInsets), name: NSView.frameDidChangeNotification, object: scrollView)
        
        self.view = scrollView
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        adjustInsets()
    }
    
    @objc func adjustInsets() {
        guard let scrollView = view as? NSScrollView else { return }
        let availableWidth = scrollView.bounds.width
        let padding = max(20, (availableWidth - currentContentWidth) / 2) // 最小 20 padding
        
        textView.textContainerInset = NSSize(width: padding, height: 40) // 固定的垂直 Padding
        textView.textContainer?.containerSize = NSSize(width: currentContentWidth, height: CGFloat.greatestFiniteMagnitude)
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
        let textColor = NSColor.labelColor.withAlphaComponent(0.9)
        textView.textColor = textColor
        
        // 设置 typingAttributes，保证新输入的文字遵循这些样式
        textView.typingAttributes = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor
        ]
        
        // 注意：如果要实时更新**已存在**的文本样式，我们需要重置整个 storage 的属性
        if textView.textStorage?.length ?? 0 > 0 {
            textView.textStorage?.addAttributes([
                .font: font,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: textColor
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
}

// 一个小的辅助类，确保点击空白处也能聚焦编辑器
class CenteredTextView: NSTextView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point) ?? self
    }
}