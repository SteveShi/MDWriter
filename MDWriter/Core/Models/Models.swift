//
//  Models.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import Foundation
import MDEditorKit
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
    case paper = "Warm Paper"
    case studio = "Studio Gray"
    case monochrome = "Monochrome"
    case solarizedLight = "Solarized Light"
    case github = "GitHub"
    case espresso = "Espresso"
    case solarizedDark = "Solarized Dark"
    case dracula = "Dracula"
    case nord = "Nord"
    case monokai = "Monokai"
    case nightOwl = "Night Owl"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .pure: return LocalizedStringKey("Pure")
        case .paper: return LocalizedStringKey("Warm Paper")
        case .studio: return LocalizedStringKey("Studio Gray")
        case .monochrome: return LocalizedStringKey("Monochrome")
        case .solarizedLight: return LocalizedStringKey("Solarized Light")
        case .github: return LocalizedStringKey("GitHub")
        case .espresso: return LocalizedStringKey("Espresso")
        case .solarizedDark: return LocalizedStringKey("Solarized Dark")
        case .dracula: return LocalizedStringKey("Dracula")
        case .nord: return LocalizedStringKey("Nord")
        case .monokai: return LocalizedStringKey("Monokai")
        case .nightOwl: return LocalizedStringKey("Night Owl")
        }
    }

    /// 判断主题色调，便于联动 SwiftUI ColorScheme。
    var isDark: Bool {
        switch self {
        case .pure, .paper, .studio, .monochrome, .solarizedLight, .github: return false
        case .espresso, .solarizedDark, .dracula, .nord, .monokai, .nightOwl: return true
        }
    }

    /// 主题在编辑器与预览面板共用的纸面背景色。
    var paperColor: Color {
        switch self {
        case .pure: return Color(red: 1.00, green: 1.00, blue: 1.00)
        case .paper: return Color(red: 0.953, green: 0.945, blue: 0.929)       // #F3F1ED 暖书纸
        case .studio: return Color(red: 0.953, green: 0.953, blue: 0.953)      // #F3F3F3 柔灰纸
        case .monochrome: return Color(red: 0.988, green: 0.988, blue: 0.988)  // #FCFCFC 素白
        case .solarizedLight: return Color(red: 0.99, green: 0.96, blue: 0.89)
        case .github: return Color(red: 0.96, green: 0.97, blue: 0.98)
        case .espresso: return Color(red: 0.165, green: 0.149, blue: 0.133)    // #2A2622 深焙胡桃
        case .solarizedDark: return Color(red: 0.00, green: 0.17, blue: 0.21)
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
        case .paper: return Color(red: 0.247, green: 0.227, blue: 0.204)       // #3F3A34
        case .studio: return Color(red: 0.290, green: 0.290, blue: 0.290)      // #4A4A4A
        case .monochrome: return Color(red: 0.149, green: 0.149, blue: 0.149)  // #262626
        case .solarizedLight: return Color(red: 0.40, green: 0.48, blue: 0.51)
        case .github: return Color(red: 0.14, green: 0.16, blue: 0.18)
        case .espresso: return Color(red: 0.937, green: 0.925, blue: 0.902)    // #EFECE6
        case .solarizedDark: return Color(red: 0.51, green: 0.58, blue: 0.59)
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
        case .paper: return Color(red: 0.271, green: 0.494, blue: 0.788)       // #457EC9
        case .studio: return Color(red: 0.000, green: 0.451, blue: 0.659)      // #0073A8
        case .monochrome: return Color(red: 0.320, green: 0.320, blue: 0.340)  // 克制中性灰
        case .solarizedLight, .solarizedDark: return Color(red: 0.15, green: 0.55, blue: 0.82)
        case .github: return Color(red: 0.01, green: 0.40, blue: 0.84)
        case .espresso: return Color(red: 0.745, green: 0.675, blue: 0.400)    // 暖金琥珀
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
                let fg = EditorThemeColor(red: 0.90, green: 0.90, blue: 0.92)
                return EditorTheme(
                    background: EditorThemeColor(red: 0.08, green: 0.08, blue: 0.09),
                    foreground: fg,
                    heading: EditorThemeColor(red: 1.00, green: 1.00, blue: 1.00),
                    syntaxMarker: EditorThemeColor(
                        red: 0.55, green: 0.55, blue: 0.60, alpha: 0.7),
                    emphasis: fg,
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

        case .paper:
            let fg = EditorThemeColor(red: 0.247, green: 0.227, blue: 0.204)
            return EditorTheme(
                background: EditorThemeColor(red: 0.953, green: 0.945, blue: 0.929),
                foreground: fg,
                heading: EditorThemeColor(red: 0.180, green: 0.160, blue: 0.140),
                syntaxMarker: EditorThemeColor(red: 0.557, green: 0.510, blue: 0.455, alpha: 0.68),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.667, green: 0.310, blue: 0.196),
                inlineCodeBackground: EditorThemeColor(red: 0.910, green: 0.896, blue: 0.868),
                codeBlockBackground: EditorThemeColor(red: 0.918, green: 0.906, blue: 0.880),
                blockquote: EditorThemeColor(red: 0.455, green: 0.420, blue: 0.380),
                link: EditorThemeColor(red: 0.271, green: 0.494, blue: 0.788),
                insertionPoint: EditorThemeColor(red: 0.533, green: 0.192, blue: 0.208)
            )

        case .studio:
            let fg = EditorThemeColor(red: 0.290, green: 0.290, blue: 0.290)
            return EditorTheme(
                background: EditorThemeColor(red: 0.953, green: 0.953, blue: 0.953),
                foreground: fg,
                heading: EditorThemeColor(red: 0.150, green: 0.150, blue: 0.150),
                syntaxMarker: EditorThemeColor(red: 0.520, green: 0.540, blue: 0.560, alpha: 0.65),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.769, green: 0.220, blue: 0.212),
                inlineCodeBackground: EditorThemeColor(red: 0.898, green: 0.902, blue: 0.908),
                codeBlockBackground: EditorThemeColor(red: 0.906, green: 0.910, blue: 0.914),
                blockquote: EditorThemeColor(red: 0.460, green: 0.470, blue: 0.490),
                link: EditorThemeColor(red: 0.000, green: 0.451, blue: 0.659),
                insertionPoint: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788)
            )

        case .monochrome:
            if appTheme == .dark {
                let fg = EditorThemeColor(red: 0.918, green: 0.918, blue: 0.918)
                return EditorTheme(
                    background: EditorThemeColor(red: 0.118, green: 0.118, blue: 0.118),
                    foreground: fg,
                    heading: EditorThemeColor(red: 1.00, green: 1.00, blue: 1.00),
                    syntaxMarker: EditorThemeColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 0.65),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.84, green: 0.84, blue: 0.86),
                    inlineCodeBackground: EditorThemeColor(red: 0.173, green: 0.173, blue: 0.180),
                    codeBlockBackground: EditorThemeColor(red: 0.165, green: 0.165, blue: 0.173),
                    blockquote: EditorThemeColor(red: 0.68, green: 0.68, blue: 0.70),
                    link: EditorThemeColor(red: 0.82, green: 0.82, blue: 0.85),
                    insertionPoint: EditorThemeColor(red: 1.00, green: 1.00, blue: 1.00)
                )
            } else {
                let fg = EditorThemeColor(red: 0.149, green: 0.149, blue: 0.149)
                return EditorTheme(
                    background: EditorThemeColor(red: 0.988, green: 0.988, blue: 0.988),
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.050, green: 0.050, blue: 0.050),
                    syntaxMarker: EditorThemeColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 0.62),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.24, green: 0.24, blue: 0.26),
                    inlineCodeBackground: EditorThemeColor(red: 0.935, green: 0.935, blue: 0.940),
                    codeBlockBackground: EditorThemeColor(red: 0.945, green: 0.945, blue: 0.950),
                    blockquote: EditorThemeColor(red: 0.42, green: 0.42, blue: 0.44),
                    link: EditorThemeColor(red: 0.24, green: 0.24, blue: 0.28),
                    insertionPoint: EditorThemeColor(red: 0.08, green: 0.08, blue: 0.08)
                )
            }

        case .espresso:
            let fg = EditorThemeColor(red: 0.937, green: 0.925, blue: 0.902)
            return EditorTheme(
                background: EditorThemeColor(red: 0.165, green: 0.149, blue: 0.133),
                foreground: fg,
                heading: EditorThemeColor(red: 0.980, green: 0.960, blue: 0.920),
                syntaxMarker: EditorThemeColor(red: 0.620, green: 0.570, blue: 0.515, alpha: 0.72),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.900, green: 0.690, blue: 0.460),
                inlineCodeBackground: EditorThemeColor(red: 0.235, green: 0.212, blue: 0.188),
                codeBlockBackground: EditorThemeColor(red: 0.220, green: 0.200, blue: 0.178),
                blockquote: EditorThemeColor(red: 0.740, green: 0.700, blue: 0.650),
                link: EditorThemeColor(red: 0.455, green: 0.710, blue: 0.835),
                insertionPoint: EditorThemeColor(red: 0.937, green: 0.820, blue: 0.500)
            )

        case .solarizedLight:
            let fg = EditorThemeColor(red: 0.40, green: 0.48, blue: 0.51)
            return EditorTheme(
                background: EditorThemeColor(red: 0.99, green: 0.96, blue: 0.89),
                foreground: fg,
                heading: EditorThemeColor(red: 0.34, green: 0.43, blue: 0.46),
                syntaxMarker: EditorThemeColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 0.7),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.86, green: 0.20, blue: 0.18),
                inlineCodeBackground: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84),
                codeBlockBackground: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84),
                blockquote: EditorThemeColor(red: 0.51, green: 0.58, blue: 0.59),
                link: EditorThemeColor(red: 0.15, green: 0.55, blue: 0.82),
                insertionPoint: EditorThemeColor(red: 0.34, green: 0.43, blue: 0.46)
            )

        case .solarizedDark:
            let fg = EditorThemeColor(red: 0.51, green: 0.58, blue: 0.59)
            return EditorTheme(
                background: EditorThemeColor(red: 0.00, green: 0.17, blue: 0.21),
                foreground: fg,
                heading: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84),
                syntaxMarker: EditorThemeColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 0.7),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.86, green: 0.20, blue: 0.18),
                inlineCodeBackground: EditorThemeColor(red: 0.03, green: 0.21, blue: 0.26),
                codeBlockBackground: EditorThemeColor(red: 0.03, green: 0.21, blue: 0.26),
                blockquote: EditorThemeColor(red: 0.40, green: 0.48, blue: 0.51),
                link: EditorThemeColor(red: 0.15, green: 0.55, blue: 0.82),
                insertionPoint: EditorThemeColor(red: 0.93, green: 0.91, blue: 0.84)
            )

        case .github:
            let fg = EditorThemeColor(red: 0.14, green: 0.16, blue: 0.18)
            return EditorTheme(
                background: EditorThemeColor(red: 0.96, green: 0.97, blue: 0.98),
                foreground: fg,
                heading: EditorThemeColor(red: 0.10, green: 0.12, blue: 0.14),
                syntaxMarker: EditorThemeColor(red: 0.42, green: 0.46, blue: 0.49, alpha: 0.65),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.85, green: 0.30, blue: 0.20),
                inlineCodeBackground: EditorThemeColor(red: 0.91, green: 0.93, blue: 0.95),
                codeBlockBackground: EditorThemeColor(red: 0.91, green: 0.93, blue: 0.95),
                blockquote: EditorThemeColor(red: 0.43, green: 0.46, blue: 0.49),
                link: EditorThemeColor(red: 0.01, green: 0.40, blue: 0.84),
                insertionPoint: EditorThemeColor(red: 0.10, green: 0.12, blue: 0.14)
            )

        case .dracula:
            let fg = EditorThemeColor(red: 0.97, green: 0.97, blue: 0.95)
            return EditorTheme(
                background: EditorThemeColor(red: 0.16, green: 0.16, blue: 0.21),
                foreground: fg,
                heading: EditorThemeColor(red: 1.00, green: 0.47, blue: 0.78),
                syntaxMarker: EditorThemeColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 0.75),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.55, green: 0.91, blue: 0.99),
                inlineCodeBackground: EditorThemeColor(red: 0.27, green: 0.28, blue: 0.35),
                codeBlockBackground: EditorThemeColor(red: 0.27, green: 0.28, blue: 0.35),
                blockquote: EditorThemeColor(red: 0.62, green: 0.62, blue: 0.71),
                link: EditorThemeColor(red: 0.55, green: 0.91, blue: 0.99),
                insertionPoint: EditorThemeColor(red: 1.00, green: 0.47, blue: 0.78)
            )

        case .nord:
            let fg = EditorThemeColor(red: 0.85, green: 0.87, blue: 0.91)
            return EditorTheme(
                background: EditorThemeColor(red: 0.18, green: 0.20, blue: 0.25),
                foreground: fg,
                heading: EditorThemeColor(red: 0.93, green: 0.94, blue: 0.96),
                syntaxMarker: EditorThemeColor(red: 0.50, green: 0.55, blue: 0.62, alpha: 0.75),
                emphasis: fg,
                inlineCode: EditorThemeColor(red: 0.65, green: 0.85, blue: 0.85),
                inlineCodeBackground: EditorThemeColor(red: 0.23, green: 0.26, blue: 0.32),
                codeBlockBackground: EditorThemeColor(red: 0.23, green: 0.26, blue: 0.32),
                blockquote: EditorThemeColor(red: 0.67, green: 0.72, blue: 0.78),
                link: EditorThemeColor(red: 0.53, green: 0.75, blue: 0.82),
                insertionPoint: EditorThemeColor(red: 0.93, green: 0.94, blue: 0.96)
            )

        case .monokai:
            let fg = EditorThemeColor(red: 0.97, green: 0.97, blue: 0.95)
            return EditorTheme(
                background: EditorThemeColor(red: 0.15, green: 0.15, blue: 0.13),
                foreground: fg,
                heading: EditorThemeColor(red: 0.96, green: 0.26, blue: 0.45),
                syntaxMarker: EditorThemeColor(red: 0.46, green: 0.46, blue: 0.43, alpha: 0.75),
                emphasis: fg,
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
    var isPinned: Bool = false  // 置顶状态
    var order: Int = 0  // 用于记录手动排序顺序
    var tags: [String] = []  // Keywords
    var folder: Folder?
    var externalFilePath: String? = nil  // 外部挂载文件夹关联路径

    @Relationship(deleteRule: .cascade, inverse: \Snapshot.note)
    var snapshots: [Snapshot] = []

    @Relationship(deleteRule: .cascade, inverse: \Memo.note)
    var memos: [Memo] = []  // Multiple separate notes

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.note)
    var chatMessages: [ChatMessage] = []

    init(title: String, content: String = "", folder: Folder? = nil, order: Int = 0, isPinned: Bool = false) {
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isTrashed = false
        self.isPinned = isPinned
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
            guard let data = try? JSONEncoder().encode(noteTransfer.id),
                  let url = URL(string: "mdwriter://note/\(data.base64EncodedString())") else {
                return URL(string: "mdwriter://note/invalid")!
            }
            return url
        })
    }
}
