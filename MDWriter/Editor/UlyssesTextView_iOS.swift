//
//  UlyssesTextView_iOS.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/19.
//

#if os(iOS)
import UIKit

class UlyssesTextView: UITextView {
    
    var currentNoteIDHash: Int = 0
    var isTypewriterModeEnabled: Bool = false
    var contentWidth: CGFloat = 700 {
        didSet {
            setNeedsLayout()
        }
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.backgroundColor = .clear
        self.isScrollEnabled = true
        self.alwaysBounceVertical = true
        self.keyboardDismissMode = .interactive
        self.allowsEditingTextAttributes = false // 禁用富文本编辑，由我们的 Storage 处理
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateInsets()
    }
    
    private func updateInsets() {
        let visibleWidth = self.bounds.width
        let padding = max(20, (visibleWidth - contentWidth) / 2)
        
        // UITextView 的 Inset 处理与 NSTextView 不同
        self.textContainerInset = UIEdgeInsets(top: 40, left: padding, bottom: 300, right: padding)
    }
    
    // MARK: - 打字机模式简易实现
    
    override var selectedRange: NSRange {
        didSet {
            if isTypewriterModeEnabled {
                scrollToCursor()
            }
        }
    }
    
    private func scrollToCursor() {
        guard let selectedTextRange = self.selectedTextRange else { return }
        let caretRect = self.caretRect(for: selectedTextRange.start)
        let centerY = self.bounds.height / 2
        let targetY = caretRect.midY - centerY
        
        if targetY > 0 {
            self.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
        }
    }
    
    // MARK: - 辅助方法
    
    func toggleWrap(prefix: String, suffix: String) {
        let range = self.selectedRange
        let text = self.text as NSString
        let selectedText = text.substring(with: range)
        
        if selectedText.hasPrefix(prefix) && selectedText.hasSuffix(suffix) {
            let inner = String(selectedText.dropFirst(prefix.count).dropLast(suffix.count))
            self.insertText(inner)
            self.selectedRange = NSRange(location: range.location, length: inner.count)
        } else {
            let wrapped = prefix + selectedText + suffix
            self.insertText(wrapped)
            self.selectedRange = NSRange(location: range.location + prefix.count, length: selectedText.count)
        }
    }
}
#endif
