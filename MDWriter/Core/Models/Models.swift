//
//  Models.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import Foundation
import MDEditor
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var markdownDocument: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
    static var noteIdentifier: UTType {
        UTType(exportedAs: "com.mdwriter.note")
    }
}

// Simplified Theme Model for Markdown
enum MarkdownTheme: String, CaseIterable, Identifiable {
    case pure = "Pure"
    case solarizedLight = "Solarized Light"
    case solarizedDark = "Solarized Dark"
    case github = "GitHub"
    case dracula = "Dracula"
    case nord = "Nord"
    case monokai = "Monokai"
    case nightOwl = "Night Owl"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .pure: return LocalizedStringKey("Pure")
        case .solarizedLight: return LocalizedStringKey("Solarized Light")
        case .solarizedDark: return LocalizedStringKey("Solarized Dark")
        case .github: return LocalizedStringKey("GitHub")
        case .dracula: return LocalizedStringKey("Dracula")
        case .nord: return LocalizedStringKey("Nord")
        case .monokai: return LocalizedStringKey("Monokai")
        case .nightOwl: return LocalizedStringKey("Night Owl")
        }
    }

    /// 判断主题色调，便于联动 SwiftUI ColorScheme。
    var isDark: Bool {
        switch self {
        case .pure, .solarizedLight, .github: return false
        case .solarizedDark, .dracula, .nord, .monokai, .nightOwl: return true
        }
    }

    /// 主题在编辑器与预览面板共用的纸面背景色。
    var paperColor: Color {
        switch self {
        case .pure: return Color(red: 1.00, green: 1.00, blue: 1.00)
        case .solarizedLight: return Color(red: 0.99, green: 0.96, blue: 0.89)
        case .solarizedDark: return Color(red: 0.00, green: 0.17, blue: 0.21)
        case .github: return Color(red: 0.96, green: 0.97, blue: 0.98)
        case .dracula: return Color(red: 0.16, green: 0.16, blue: 0.21)
        case .nord: return Color(red: 0.18, green: 0.20, blue: 0.25)
        case .monokai: return Color(red: 0.15, green: 0.15, blue: 0.13)
        case .nightOwl: return Color(red: 0.00, green: 0.09, blue: 0.15)
        }
    }

    /// 主题在编辑器与预览面板共用的正文文本色。
    var textColor: Color {
        switch self {
        case .pure: return Color(red: 0.13, green: 0.13, blue: 0.13)
        case .solarizedLight: return Color(red: 0.40, green: 0.48, blue: 0.51)
        case .solarizedDark: return Color(red: 0.51, green: 0.58, blue: 0.59)
        case .github: return Color(red: 0.14, green: 0.16, blue: 0.18)
        case .dracula: return Color(red: 0.97, green: 0.97, blue: 0.95)
        case .nord: return Color(red: 0.85, green: 0.87, blue: 0.91)
        case .monokai: return Color(red: 0.97, green: 0.97, blue: 0.95)
        case .nightOwl: return Color(red: 0.84, green: 0.87, blue: 0.92)
        }
    }

    /// 主题的强调色（链接、行内代码等）。
    var accentColor: Color {
        switch self {
        case .pure: return Color(red: 0.00, green: 0.48, blue: 1.00)
        case .solarizedLight, .solarizedDark: return Color(red: 0.15, green: 0.55, blue: 0.82)
        case .github: return Color(red: 0.01, green: 0.40, blue: 0.84)
        case .dracula: return Color(red: 0.55, green: 0.91, blue: 0.99)
        case .nord: return Color(red: 0.53, green: 0.75, blue: 0.82)
        case .monokai: return Color(red: 0.40, green: 0.85, blue: 0.94)
        case .nightOwl: return Color(red: 0.51, green: 0.67, blue: 1.00)
        }
    }

    /// 将枚举映射成 MDEditor 编辑器主题，使 8 个配色在编辑器画面内生效。
    /// - Parameter appTheme: 当前 AppTheme，仅在 Pure 主题需要根据明暗切换文字配色时生效；
    ///   其它主题自带固定明暗，不依赖此参数。
    func editorTheme(for appTheme: AppTheme = .light) -> EditorTheme {
        switch self {
        case .pure:
            switch appTheme {
            case .light:
                return .default
            case .dark:
                // Pure + Dark：使用与 AppTheme.dark.paperColor 一致的深色纸面，
                // 文字与标题切到高对比度亮色，避免出现"黑底接近黑字"的不可读情况。
                return EditorTheme(
                    background: EditorThemeColor(red: 0.08, green: 0.08, blue: 0.09),
                    foreground: EditorThemeColor(red: 0.90, green: 0.90, blue: 0.92),
                    heading: EditorThemeColor(red: 1.00, green: 1.00, blue: 1.00),
                    syntaxMarker: EditorThemeColor(
                        red: 0.55, green: 0.55, blue: 0.60, alpha: 0.7),
                    emphasis: EditorThemeColor(red: 0.97, green: 0.83, blue: 0.45),
                    inlineCode: EditorThemeColor(red: 0.95, green: 0.60, blue: 0.55),
                    inlineCodeBackground: EditorThemeColor(
                        red: 0.16, green: 0.16, blue: 0.19),
                    codeBlockBackground: EditorThemeColor(
                        red: 0.16, green: 0.16, blue: 0.19),
                    blockquote: EditorThemeColor(red: 0.65, green: 0.67, blue: 0.72),
                    link: EditorThemeColor(red: 0.40, green: 0.60, blue: 1.00),
                    insertionPoint: EditorThemeColor(red: 1.00, green: 1.00, blue: 1.00)
                )
            }

        case .solarizedLight:
            return EditorTheme(
                background: EditorThemeColor(red: 0.99, green: 0.96, blue: 0.89),
                foreground: EditorThemeColor(red: 0.40, green: 0.48, blue: 0.51),
                heading: EditorThemeColor(red: 0.34, green: 0.43, blue: 0.46),
                syntaxMarker: EditorThemeColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 0.7),
                emphasis: EditorThemeColor(red: 0.71, green: 0.54, blue: 0.00),
                inlineCode: EditorThemeColor(red: 0.86, green: 0.20, blue: 0.18),
                inlineCodeBackground: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84),
                codeBlockBackground: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84),
                blockquote: EditorThemeColor(red: 0.51, green: 0.58, blue: 0.59),
                link: EditorThemeColor(red: 0.15, green: 0.55, blue: 0.82),
                insertionPoint: EditorThemeColor(red: 0.34, green: 0.43, blue: 0.46)
            )

        case .solarizedDark:
            return EditorTheme(
                background: EditorThemeColor(red: 0.00, green: 0.17, blue: 0.21),
                foreground: EditorThemeColor(red: 0.51, green: 0.58, blue: 0.59),
                heading: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84),
                syntaxMarker: EditorThemeColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 0.7),
                emphasis: EditorThemeColor(red: 0.71, green: 0.54, blue: 0.00),
                inlineCode: EditorThemeColor(red: 0.86, green: 0.20, blue: 0.18),
                inlineCodeBackground: EditorThemeColor(red: 0.03, green: 0.21, blue: 0.26),
                codeBlockBackground: EditorThemeColor(red: 0.03, green: 0.21, blue: 0.26),
                blockquote: EditorThemeColor(red: 0.40, green: 0.48, blue: 0.51),
                link: EditorThemeColor(red: 0.15, green: 0.55, blue: 0.82),
                insertionPoint: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84)
            )

        case .github:
            return EditorTheme(
                background: EditorThemeColor(red: 0.96, green: 0.97, blue: 0.98),
                foreground: EditorThemeColor(red: 0.14, green: 0.16, blue: 0.18),
                heading: EditorThemeColor(red: 0.10, green: 0.12, blue: 0.14),
                syntaxMarker: EditorThemeColor(red: 0.42, green: 0.46, blue: 0.49, alpha: 0.65),
                emphasis: EditorThemeColor(red: 0.85, green: 0.30, blue: 0.20),
                inlineCode: EditorThemeColor(red: 0.85, green: 0.30, blue: 0.20),
                inlineCodeBackground: EditorThemeColor(red: 0.91, green: 0.93, blue: 0.95),
                codeBlockBackground: EditorThemeColor(red: 0.91, green: 0.93, blue: 0.95),
                blockquote: EditorThemeColor(red: 0.43, green: 0.46, blue: 0.49),
                link: EditorThemeColor(red: 0.01, green: 0.40, blue: 0.84),
                insertionPoint: EditorThemeColor(red: 0.10, green: 0.12, blue: 0.14)
            )

        case .dracula:
            return EditorTheme(
                background: EditorThemeColor(red: 0.16, green: 0.16, blue: 0.21),
                foreground: EditorThemeColor(red: 0.97, green: 0.97, blue: 0.95),
                heading: EditorThemeColor(red: 1.00, green: 0.47, blue: 0.78),
                syntaxMarker: EditorThemeColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 0.75),
                emphasis: EditorThemeColor(red: 1.00, green: 0.72, blue: 0.42),
                inlineCode: EditorThemeColor(red: 0.55, green: 0.91, blue: 0.99),
                inlineCodeBackground: EditorThemeColor(red: 0.27, green: 0.28, blue: 0.35),
                codeBlockBackground: EditorThemeColor(red: 0.27, green: 0.28, blue: 0.35),
                blockquote: EditorThemeColor(red: 0.62, green: 0.62, blue: 0.71),
                link: EditorThemeColor(red: 0.55, green: 0.91, blue: 0.99),
                insertionPoint: EditorThemeColor(red: 1.00, green: 0.47, blue: 0.78)
            )

        case .nord:
            return EditorTheme(
                background: EditorThemeColor(red: 0.18, green: 0.20, blue: 0.25),
                foreground: EditorThemeColor(red: 0.85, green: 0.87, blue: 0.91),
                heading: EditorThemeColor(red: 0.93, green: 0.94, blue: 0.96),
                syntaxMarker: EditorThemeColor(red: 0.50, green: 0.55, blue: 0.62, alpha: 0.75),
                emphasis: EditorThemeColor(red: 0.92, green: 0.80, blue: 0.55),
                inlineCode: EditorThemeColor(red: 0.65, green: 0.85, blue: 0.85),
                inlineCodeBackground: EditorThemeColor(red: 0.23, green: 0.26, blue: 0.32),
                codeBlockBackground: EditorThemeColor(red: 0.23, green: 0.26, blue: 0.32),
                blockquote: EditorThemeColor(red: 0.67, green: 0.72, blue: 0.78),
                link: EditorThemeColor(red: 0.53, green: 0.75, blue: 0.82),
                insertionPoint: EditorThemeColor(red: 0.93, green: 0.94, blue: 0.96)
            )

        case .monokai:
            return EditorTheme(
                background: EditorThemeColor(red: 0.15, green: 0.15, blue: 0.13),
                foreground: EditorThemeColor(red: 0.97, green: 0.97, blue: 0.95),
                heading: EditorThemeColor(red: 0.96, green: 0.26, blue: 0.45),
                syntaxMarker: EditorThemeColor(red: 0.46, green: 0.46, blue: 0.43, alpha: 0.75),
                emphasis: EditorThemeColor(red: 0.65, green: 0.89, blue: 0.18),
                inlineCode: EditorThemeColor(red: 0.40, green: 0.85, blue: 0.94),
                inlineCodeBackground: EditorThemeColor(red: 0.24, green: 0.24, blue: 0.20),
                codeBlockBackground: EditorThemeColor(red: 0.24, green: 0.24, blue: 0.20),
                blockquote: EditorThemeColor(red: 0.73, green: 0.73, blue: 0.68),
                link: EditorThemeColor(red: 0.40, green: 0.85, blue: 0.94),
                insertionPoint: EditorThemeColor(red: 0.96, green: 0.26, blue: 0.45)
            )

        case .nightOwl:
            return EditorTheme(
                background: EditorThemeColor(red: 0.00, green: 0.09, blue: 0.15),
                foreground: EditorThemeColor(red: 0.84, green: 0.87, blue: 0.92),
                heading: EditorThemeColor(red: 0.95, green: 0.78, blue: 0.45),
                syntaxMarker: EditorThemeColor(red: 0.37, green: 0.49, blue: 0.59, alpha: 0.8),
                emphasis: EditorThemeColor(red: 0.91, green: 0.66, blue: 0.59),
                inlineCode: EditorThemeColor(red: 0.51, green: 0.67, blue: 1.00),
                inlineCodeBackground: EditorThemeColor(red: 0.04, green: 0.16, blue: 0.26),
                codeBlockBackground: EditorThemeColor(red: 0.04, green: 0.16, blue: 0.26),
                blockquote: EditorThemeColor(red: 0.50, green: 0.62, blue: 0.74),
                link: EditorThemeColor(red: 0.51, green: 0.67, blue: 1.00),
                insertionPoint: EditorThemeColor(red: 0.95, green: 0.78, blue: 0.45)
            )
        }
    }
}

@Model
final class Folder {
    var name: String
    var createdAt: Date
    var icon: String

    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note] = []

    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var subfolders: [Folder] = []

    var parent: Folder?

    init(name: String, icon: String = "folder") {
        self.name = name
        self.icon = icon
        self.createdAt = Date()
    }
}

@Model
final class Note {
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isTrashed: Bool = false
    var order: Int = 0  // 用于记录手动排序顺序
    var tags: [String] = []  // Keywords
    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Snapshot.note)
    var snapshots: [Snapshot] = []

    @Relationship(deleteRule: .cascade, inverse: \Memo.note)
    var memos: [Memo] = []  // Multiple separate notes

    init(title: String, content: String = "", folder: Folder? = nil, order: Int = 0) {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isTrashed = false
        self.folder = folder
        self.order = order
    }
}

@Model
final class Memo {
    var content: String
    var createdAt: Date
    var note: Note?

    init(content: String, note: Note? = nil) {
        self.content = content
        self.createdAt = Date()
        self.note = note
    }
}

@Model
final class Snapshot {
    var content: String
    var createdAt: Date
    var note: Note?

    init(content: String, note: Note? = nil) {
        self.content = content
        self.createdAt = Date()
        self.note = note
    }
}

struct NoteTransfer: Codable, Transferable, Sendable {
    let id: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: { noteTransfer in
            let data = try! JSONEncoder().encode(noteTransfer.id)
            let base64 = data.base64EncodedString()
            return URL(string: "mdwriter://note/\(base64)")!
        })
    }
}
