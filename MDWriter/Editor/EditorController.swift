//
//  EditorController.swift
//  MDWriter
//

import Combine
import Foundation
import MDEditor

class EditorController: ObservableObject {

    // MARK: - Proxy Instance

    /// 编辑器交互代理
    let proxy = MDEditorProxy()

    // MARK: - Published State

    @Published var isMarkupBarVisible: Bool = false
    @Published var isSearchVisible: Bool = false

    // Search & Replace State
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var isReplaceVisible: Bool = false

    // MARK: - Basic Insert

    func insert(_ text: String) {
        proxy.insert(text)
    }

    func insertMarkup(_ markup: String) {
        proxy.insert(markup)
    }

    // MARK: - Formatting Toggles (Wrapping)

    func toggleBold() {
        proxy.wrapSelection(prefix: "**", suffix: "**")
    }

    func toggleItalic() {
        proxy.wrapSelection(prefix: "*", suffix: "*")
    }

    func toggleStrikethrough() {
        proxy.wrapSelection(prefix: "~~", suffix: "~~")
    }

    func toggleInlineCode() {
        proxy.wrapSelection(prefix: "`", suffix: "`")
    }

    func toggleCodeBlock() {
        proxy.wrapSelection(prefix: "```\n", suffix: "\n```")
    }

    // MARK: - Special Inserts

    func insertLinkMarkup() {
        if let selectedText = proxy.getSelectedText(), !selectedText.isEmpty {
            proxy.insert("[\(selectedText)](url)")
        } else {
            proxy.insert("[text](url)")
        }
    }

    func insertImageMarkup() {
        proxy.insert("![alt text](image_url)")
    }

    // MARK: - Markup Bar Toggle

    func toggleMarkupBar() {
        isMarkupBarVisible.toggle()
    }

    // MARK: - Find & Replace Methods

    func findNext() {
        proxy.findNext(text: searchText)
    }

    func findPrevious() {
        proxy.findPrevious(text: searchText)
    }

    func replace() {
        proxy.replace(search: searchText, with: replaceText)
    }

    func replaceAll() {
        proxy.replaceAll(search: searchText, with: replaceText)
    }
}
