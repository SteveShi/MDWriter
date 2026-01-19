import Combine
import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct UlyssesEditor: View {
    @Binding var text: String
    var noteID: PersistentIdentifier?
    var configuration: EditorConfiguration
    @ObservedObject var controller: EditorController
    @AppStorage("appTheme") private var appTheme: AppTheme = .light

    var body: some View {
        #if os(macOS)
        UlyssesEditorMacOS(text: $text, noteID: noteID, configuration: configuration, controller: controller, appTheme: appTheme)
        #else
        ZStack(alignment: .bottom) {
            UlyssesEditoriOS(text: $text, noteID: noteID, configuration: configuration, controller: controller, appTheme: appTheme)
            IOSMarkupBar(controller: controller)
        }
        #endif
    }
}

// MARK: - MacOS Implementation
#if os(macOS)
struct UlyssesEditorMacOS: NSViewRepresentable {
    @Binding var text: String
    var noteID: PersistentIdentifier?
    var configuration: EditorConfiguration
    var controller: EditorController
    var appTheme: AppTheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        
        let textStorage = MarkdownTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: configuration.contentWidth, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        let textView = UlyssesTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? UlyssesTextView else { return }
        updateCommonView(textView, textStorage: textView.textStorage as? MarkdownTextStorage, context: context)
    }

    private func updateCommonView(_ textView: UlyssesTextView, textStorage: MarkdownTextStorage?, context: Context) {
        context.coordinator.parent = self
        guard let textStorage = textStorage else { return }
        
        controller.insertTextAction = { [weak textView] t in textView?.insertText(t, replacementRange: textView?.selectedRange() ?? NSRange()) }
        controller.wrapSelectionAction = { [weak textView] p, s in textView?.toggleWrap(prefix: p, suffix: s) }
        
        textView.isTypewriterModeEnabled = configuration.typewriterMode
        textView.contentWidth = configuration.contentWidth
        textStorage.baseFont = configuration.platformFont
        textStorage.lineHeightMultiple = configuration.lineHeightMultiple
        
        if textStorage.theme != appTheme {
            textStorage.theme = appTheme
            textStorage.forceHighlight()
        }

        let newHash = noteID?.hashValue ?? 0
        if textView.currentNoteIDHash != newHash {
            textView.currentNoteIDHash = newHash
            textView.undoManager?.removeAllActions()
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: text)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        } else if textView.string != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: text)
            context.coordinator.isUpdatingFromSwiftUI = false
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: UlyssesEditorMacOS
        var isUpdatingFromSwiftUI = false
        weak var textView: UlyssesTextView?
        init(_ parent: UlyssesEditorMacOS) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, !isUpdatingFromSwiftUI else { return }
            parent.text = tv.string
        }
    }
}
#endif

// MARK: - iOS Implementation
#if os(iOS)
struct UlyssesEditoriOS: UIViewRepresentable {
    @Binding var text: String
    var noteID: PersistentIdentifier?
    var configuration: EditorConfiguration
    var controller: EditorController
    var appTheme: AppTheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }

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
        updateCommonView(uiView, textStorage: uiView.textStorage as? MarkdownTextStorage, context: context)
    }

    private func updateCommonView(_ textView: UlyssesTextView, textStorage: MarkdownTextStorage?, context: Context) {
        context.coordinator.parent = self
        guard let textStorage = textStorage else { return }
        
        controller.insertTextAction = { [weak textView] t in textView?.insertText(t) }
        controller.wrapSelectionAction = { [weak textView] p, s in textView?.toggleWrap(prefix: p, suffix: s) }
        
        textView.isTypewriterModeEnabled = configuration.typewriterMode
        textView.contentWidth = configuration.contentWidth
        textStorage.baseFont = configuration.platformFont
        textStorage.lineHeightMultiple = configuration.lineHeightMultiple
        
        if textStorage.theme != appTheme {
            textStorage.theme = appTheme
            textStorage.forceHighlight()
        }

        let newHash = noteID?.hashValue ?? 0
        if textView.currentNoteIDHash != newHash {
            textView.currentNoteIDHash = newHash
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: text)
            textView.selectedRange = NSRange(location: 0, length: 0)
        } else if textView.text != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: text)
            context.coordinator.isUpdatingFromSwiftUI = false
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UlyssesEditoriOS
        var isUpdatingFromSwiftUI = false
        weak var textView: UlyssesTextView?
        init(_ parent: UlyssesEditoriOS) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            if !isUpdatingFromSwiftUI { parent.text = textView.text }
        }
    }
}
#endif