//
//  MarkdownStructure.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import Foundation
import Markdown

struct DocumentHeader: Identifiable, Hashable {
    let id = UUID()
    let level: Int
    let title: String
    let lineIndex: Int
}

class MDHeaderParser {
    static func parseHeaders(from text: String) -> [DocumentHeader] {
        let document = Document(parsing: text)
        var visitor = HeaderVisitor()
        visitor.visit(document)
        return visitor.headers
    }
}

private struct HeaderVisitor: MarkupVisitor {
    typealias Result = Void
    var headers: [DocumentHeader] = []

    mutating func defaultVisit(_ markup: Markup) {
        for child in markup.children {
            visit(child)
        }
    }
    mutating func visitHeading(_ heading: Heading) {
        let title = heading.plainText
        let level = heading.level
        let lineIndex = heading.range?.lowerBound.line ?? 0

        // swift-markdown line indices are 1-based, we'll convert to 0-based to match existing logic
        headers.append(DocumentHeader(level: level, title: title, lineIndex: max(0, lineIndex - 1)))
    }
}

struct DocumentStatistics {
    let characters: Int
    let words: Int
    let readingTime: Int  // 分钟

    static func calculate(from text: String) -> DocumentStatistics {
        let charCount = text.count

        // Use swift-markdown to extract plain text for more accurate word counting (ignore markup)
        let document = Document(parsing: text)
        let plainText = document.plainText

        let wordCount = plainText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count

        // Assume reading speed of 300 words/min
        let time = max(1, Int(ceil(Double(wordCount) / 300.0)))

        return DocumentStatistics(characters: charCount, words: wordCount, readingTime: time)
    }
}

extension Markup {
    var plainText: String {
        var visitor = PlainTextVisitor()
        visitor.visit(self)
        return visitor.text
    }
}

private struct PlainTextVisitor: MarkupVisitor {
    typealias Result = Void
    var text = ""

    mutating func defaultVisit(_ markup: Markup) {
        for child in markup.children {
            visit(child)
        }
    }

    mutating func visitText(_ text: Markdown.Text) {
        self.text += text.string
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        text += " "
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        text += "\n"
    }
}
