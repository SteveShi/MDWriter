//
//  MarkdownStructure.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import Foundation
import MDEditorKit

struct DocumentHeader: Identifiable, Hashable {
    let id = UUID()
    let level: Int
    let title: String
    let lineIndex: Int
}

struct MDHeaderParser {
    static func parseHeaders(from text: String) -> [DocumentHeader] {
        MarkdownConverter.headers(from: text).map {
            DocumentHeader(level: $0.level, title: $0.title, lineIndex: $0.lineIndex)
        }
    }
}

struct DocumentStatistics {
    let characters: Int
    let words: Int
    let readingTime: Int  // 分钟

    static func calculate(from text: String) -> DocumentStatistics {
        let stats = MarkdownConverter.statistics(from: text)
        return DocumentStatistics(
            characters: stats.characters,
            words: stats.words,
            readingTime: stats.readingTime
        )
    }
}
