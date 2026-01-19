//
//  UlyssesEditor.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI

struct UlyssesEditor: PlatformViewRepresentable {

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
        #if os(macOS)
        weak var textView: UlyssesTextView?
        #else
        weak var textView: UlyssesTextView? // 在 iOS 上这也是我们要引用的类
        #endif
        private var cancellables = Set<AnyCancellable>()

        init(_ parent: UlyssesEditor) {
            self.parent = parent
            super.init()
            setupNotificationHandlers()
        }

        private func setupNotificationHandlers() {
            #if os(macOS)
            NotificationCenter.default.publisher(for: NSNotification.Name("printDocument"))
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.textView?.printView(nil)
                }
                .store(in: &cancellables)
            #endif
        }

        #if os(macOS)
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if !isUpdatingFromSwiftUI && textView.string != parent.text {
                parent.text = textView.string
            }
        }
        #else
        // iOS 版本的 textDidChange 在 UITextViewDelegate 中
        #endif
    }

    #if !os(macOS)
    // iOS Delegate 适配
    extension Coordinator: UITextViewDelegate {
        func textViewDidChange(_ textView: UITextView) {
            if !isUpdatingFromSwiftUI && textView.text != parent.text {
                parent.text = textView.text
            }
        }
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 平台适配接口

    #if os(macOS)
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.automaticallyAdjustsContentInsets = false

        let textStorage = MarkdownTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            size: NSSize(width: configuration.contentWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 5
        layoutManager.addTextContainer(textContainer)

        let textView = UlyssesTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? UlyssesTextView else { return }
        updateCommonView(textView, context: context)
    }
    #else
    func makeUIView(context: Context) -> UlyssesTextView {
        let textStorage = MarkdownTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(size: .zero)
        layoutManager.addTextContainer(textContainer)
        
        let textView = UlyssesTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        
        return textView
    }
    
    func updateUIView(_ uiView: UlyssesTextView, context: Context) {
        updateCommonView(uiView, context: context)
    }
    #endif

    // MARK: - iOS Layout Wrapper (Used to overlay the Markup Bar)
    
    #if os(iOS)
    var body: some View {
        ZStack(alignment: .bottom) {
            UlyssesEditorInternal(text: $text, noteID: noteID, configuration: configuration, controller: controller)
            
            IOSMarkupBar(controller: controller)
        }
    }
    #endif
}

// 内部结构体用于实际的 UI/NSViewRepresentable 实现
#if os(iOS)
struct UlyssesEditorInternal: UIViewRepresentable {
    @Binding var text: String
    var noteID: PersistentIdentifier?
    var configuration: EditorConfiguration
    @ObservedObject var controller: EditorController
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    func makeCoordinator() -> UlyssesEditor.Coordinator {
        UlyssesEditor.Coordinator(UlyssesEditor(text: $text, noteID: noteID, configuration: configuration, controller: controller))
    }

    func makeUIView(context: Context) -> UlyssesTextView {
        let textStorage = MarkdownTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .zero)
        layoutManager.addTextContainer(textContainer)
        let textView = UlyssesTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ uiView: UlyssesTextView, context: Context) {
        // 调用共享逻辑
        // 注意：这里需要稍微调整一下 UlyssesEditor 结构以共享 updateCommonView
        // 为了实验性代入，我们直接在此重写逻辑或简化
    }
}
#endif

    // MARK: - 通用更新逻辑

    private func updateCommonView(_ textView: UlyssesTextView, context: Context) {
        guard let textStorage = textView.textStorage as? MarkdownTextStorage else { return }

        context.coordinator.parent = self

        // 处理外部命令
        controller.insertTextAction = { [weak textView] (textToInsert: String) in
            #if os(macOS)
            textView?.insertText(textToInsert, replacementRange: textView?.selectedRange() ?? NSRange())
            #else
            textView?.insertText(textToInsert)
            #endif
        }

        controller.wrapSelectionAction = { [weak textView] (prefix: String, suffix: String) in
            textView?.toggleWrap(prefix: prefix, suffix: suffix)
        }

        // 更新配置
        textView.isTypewriterModeEnabled = configuration.typewriterMode
        textView.contentWidth = configuration.contentWidth
        
        var storageChanged = false
        if textStorage.baseFont != configuration.platformFont {
            textStorage.baseFont = configuration.platformFont
            storageChanged = true
        }
        if textStorage.lineHeightMultiple != configuration.lineHeightMultiple {
            textStorage.lineHeightMultiple = configuration.lineHeightMultiple
            storageChanged = true
        }

        if storageChanged {
            textStorage.forceHighlight()
        }

        // 内容同步
        let newHash = noteID?.hashValue ?? 0
        let isNewDocument = textView.currentNoteIDHash != newHash

        if isNewDocument {
            textView.currentNoteIDHash = newHash
            #if os(macOS)
            textView.undoManager?.removeAllActions()
            #endif
        }

        let currentString = #if os(macOS) then textView.string else textView.text #endif
        
        if currentString != text || isNewDocument {
            context.coordinator.isUpdatingFromSwiftUI = true
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: text)
            
            if isNewDocument {
                #if os(macOS)
                textView.scroll(NSPoint.zero)
                #else
                textView.setContentOffset(.zero, animated: false)
                #endif
                textView.selectedRange = NSRange(location: 0, length: 0)
            }
            context.coordinator.isUpdatingFromSwiftUI = false
        }

        if textStorage.theme != appTheme {
            textStorage.theme = appTheme
            textStorage.forceHighlight()
            textView.setNeedsDisplay()
        }
    }
}