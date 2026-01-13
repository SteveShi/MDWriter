//
//  EditorController.swift
//  MDWriter
//

import Combine
import Foundation

class EditorController: ObservableObject {

    // MARK: - Actions (Set by UlyssesEditor)

    var insertTextAction: ((String) -> Void)?
    var wrapSelectionAction: ((String, String) -> Void)?
    var getSelectedTextAction: (() -> String?)?

    // MARK: - Published State

    @Published var isMarkupBarVisible: Bool = false

    // MARK: - Basic Insert

    func insert(_ text: String) {
        insertTextAction?(text)
    }

    func insertMarkup(_ markup: String) {
        insertTextAction?(markup)
    }

    // MARK: - Formatting Toggles (Wrapping)

    func toggleBold() {
        wrapSelectionAction?("**", "**")
    }

    func toggleItalic() {
        wrapSelectionAction?("*", "*")
    }

    func toggleStrikethrough() {
        wrapSelectionAction?("~~", "~~")
    }

    func toggleInlineCode() {
        wrapSelectionAction?("`", "`")
    }

    func toggleCodeBlock() {
        wrapSelectionAction?("```\n", "\n```")
    }

    // MARK: - Special Inserts

    func insertLinkMarkup() {
        if let selectedText = getSelectedTextAction?(), !selectedText.isEmpty {
            insertTextAction?("[\(selectedText)](url)")
        } else {
            insertTextAction?("[text](url)")
        }
    }

    func insertImageMarkup() {
        insertTextAction?("![alt text](image_url)")
    }

    // MARK: - Markup Bar Toggle

    func toggleMarkupBar() {
        isMarkupBarVisible.toggle()
    }
}
