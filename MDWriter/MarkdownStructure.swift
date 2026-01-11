//
//  MarkdownStructure.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import Foundation

struct DocumentHeader: Identifiable, Hashable {
    let id = UUID()
    let level: Int
    let title: String
    let lineIndex: Int
}

class MarkdownParser {
    static func parseHeaders(from text: String) -> [DocumentHeader] {
        var headers: [DocumentHeader] = []
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("#") {
                let trimming = line.trimmingCharacters(in: .whitespaces)
                let level = trimming.prefix(while: { $0 == "#" }).count
                // 限制只提取 1-6 级标题
                if level > 0 && level <= 6 {
                    let title = String(trimming.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        headers.append(DocumentHeader(level: level, title: title, lineIndex: index))
                    }
                }
            }
        }
        return headers
    }
}

struct DocumentStatistics {
    let characters: Int
    let words: Int
    let readingTime: Int // 分钟
    
    static func calculate(from text: String) -> DocumentStatistics {
        let charCount = text.count
        // 简单的字数统计（适用于中英文混排）
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }.count
        
        // 假设阅读速度为 300 字/分钟
        let time = max(1, Int(ceil(Double(wordCount) / 300.0)))
        
        return DocumentStatistics(characters: charCount, words: wordCount, readingTime: time)
    }
}
