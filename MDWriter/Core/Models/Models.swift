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

// Dual-Mode Theme Model (Every theme adapts natively to both Light & Dark appearances,
// directly modeled on Ulysses 42.2's official dual-palette Theme.xml system).
enum MarkdownTheme: String, CaseIterable, Identifiable {
    case pure = "Pure"                 // Ulysses Default (default-macos-39)
    case paper = "Warm Paper"          // Ulysses Simple (simple)
    case studio = "Studio Gray"        // Ulysses Freestraction (freestraction)
    case monochrome = "Monochrome"     // Ulysses D26 Mono (d26-mono)
    case d22 = "D22"                   // Ulysses D22 (pure OLED dark)
    case solarized = "Solarized"       // Ulysses Solarized (light + dark)
    case yosemite = "Yosemite"         // Ulysses Yosemite (classic cyan/magenta)
    case nord = "Nord"                 // Nord (Snow Storm light + Polar Night dark)

    var id: String { rawValue }

    /// 兼容早期版本保存在 UserDefaults 中的旧主题名，无缝迁移至双模式主题。
    static func fromStorage(_ raw: String?) -> MarkdownTheme {
        guard let raw else { return .pure }
        if let exact = MarkdownTheme(rawValue: raw) {
            return exact
        }
        switch raw {
        case "Espresso": return .paper
        case "Solarized Light", "Solarized Dark": return .solarized
        case "GitHub": return .pure
        case "Dracula", "Night Owl": return .d22
        case "Monokai": return .studio
        default: return .pure
        }
    }

    var displayName: LocalizedStringKey {
        switch self {
        case .pure: return LocalizedStringKey("Default")
        case .paper: return LocalizedStringKey("Warm Paper")
        case .studio: return LocalizedStringKey("Freestraction")
        case .monochrome: return LocalizedStringKey("D26 Mono")
        case .d22: return LocalizedStringKey("D22")
        case .solarized: return LocalizedStringKey("Solarized")
        case .yosemite: return LocalizedStringKey("Yosemite")
        case .nord: return LocalizedStringKey("Nord")
        }
    }

    /// 当前主题在指定明暗模式下的纸面背景色。
    func paperColor(isDark: Bool) -> Color {
        switch self {
        case .pure:
            return isDark
                ? Color(red: 0.118, green: 0.118, blue: 0.118) // #1E1E1E
                : Color(red: 1.000, green: 1.000, blue: 1.000) // #FFFFFF
        case .paper:
            return isDark
                ? Color(red: 0.180, green: 0.165, blue: 0.149) // #2E2A26 深焙暖棕
                : Color(red: 0.953, green: 0.945, blue: 0.929) // #F3F1ED 暖书纸
        case .studio:
            return isDark
                ? Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
                : Color(red: 0.953, green: 0.953, blue: 0.953) // #F3F3F3
        case .monochrome:
            return isDark
                ? Color(red: 0.118, green: 0.118, blue: 0.118) // #1E1E1E
                : Color(red: 0.992, green: 0.992, blue: 0.992) // #FDFDFD
        case .d22:
            return isDark
                ? Color(red: 0.000, green: 0.000, blue: 0.000) // #000000 OLED 纯黑
                : Color(red: 1.000, green: 1.000, blue: 1.000) // #FFFFFF
        case .solarized:
            return isDark
                ? Color(red: 0.000, green: 0.169, blue: 0.212) // #002B36
                : Color(red: 0.996, green: 0.969, blue: 0.886) // #FEF7E2
        case .yosemite:
            return isDark
                ? Color(red: 0.157, green: 0.157, blue: 0.157) // #282828
                : Color(red: 1.000, green: 1.000, blue: 1.000) // #FFFFFF
        case .nord:
            return isDark
                ? Color(red: 0.180, green: 0.204, blue: 0.251) // #2E3440
                : Color(red: 0.925, green: 0.937, blue: 0.957) // #ECEFF4
        }
    }

    /// 当前主题在指定明暗模式下的正文前景色。
    func textColor(isDark: Bool) -> Color {
        switch self {
        case .pure:
            return isDark
                ? Color(red: 0.918, green: 0.918, blue: 0.918) // #EAEAEA
                : Color(red: 0.149, green: 0.149, blue: 0.149) // #262626
        case .paper:
            return isDark
                ? Color(red: 0.953, green: 0.945, blue: 0.929) // #F3F1ED
                : Color(red: 0.247, green: 0.227, blue: 0.204) // #3F3A34
        case .studio:
            return isDark
                ? Color(red: 0.780, green: 0.780, blue: 0.780) // #C7C7C7
                : Color(red: 0.314, green: 0.314, blue: 0.314) // #505050
        case .monochrome:
            return isDark
                ? Color(red: 0.918, green: 0.918, blue: 0.918) // #EAEAEA
                : Color(red: 0.149, green: 0.149, blue: 0.149) // #262626
        case .d22:
            return isDark
                ? Color(red: 0.918, green: 0.918, blue: 0.918) // #EAEAEA
                : Color(red: 0.149, green: 0.149, blue: 0.149) // #262626
        case .solarized:
            return isDark
                ? Color(red: 0.576, green: 0.631, blue: 0.631) // #93A1A1
                : Color(red: 0.333, green: 0.431, blue: 0.459) // #556E75
        case .yosemite:
            return isDark
                ? Color(red: 0.816, green: 0.816, blue: 0.816) // #D0D0D0
                : Color(red: 0.137, green: 0.137, blue: 0.137) // #232323
        case .nord:
            return isDark
                ? Color(red: 0.847, green: 0.871, blue: 0.914) // #D8DEE9
                : Color(red: 0.180, green: 0.204, blue: 0.251) // #2E3440
        }
    }

    /// 当前主题在指定明暗模式下的强调色（链接、标题点缀、色板预览等）。
    func accentColor(isDark: Bool) -> Color {
        switch self {
        case .pure:
            return isDark
                ? Color(red: 0.000, green: 0.569, blue: 1.000) // #0091FF
                : Color(red: 0.000, green: 0.533, blue: 1.000) // #0088FF
        case .paper:
            return isDark
                ? Color(red: 0.380, green: 0.714, blue: 0.878) // #61B6E0
                : Color(red: 0.271, green: 0.494, blue: 0.788) // #457EC9
        case .studio:
            return isDark
                ? Color(red: 0.161, green: 0.714, blue: 0.878) // #29B6E0
                : Color(red: 0.000, green: 0.608, blue: 0.788) // #009BC9
        case .monochrome:
            return isDark
                ? Color(red: 0.680, green: 0.680, blue: 0.700)
                : Color(red: 0.320, green: 0.320, blue: 0.340)
        case .d22:
            return isDark
                ? Color(red: 0.039, green: 0.518, blue: 1.000) // #0A84FF
                : Color(red: 0.000, green: 0.478, blue: 1.000) // #007AFF
        case .solarized:
            return Color(red: 0.008, green: 0.541, blue: 0.831) // #028AD4
        case .yosemite:
            return Color(red: 0.000, green: 0.608, blue: 0.788) // #009BC9
        case .nord:
            return isDark
                ? Color(red: 0.533, green: 0.753, blue: 0.816) // #88C0D0
                : Color(red: 0.369, green: 0.506, blue: 0.675) // #5E81AC
        }
    }

    /// 兼容旧调用的默认亮色背景访问器。
    var paperColor: Color { paperColor(isDark: false) }
    var textColor: Color { textColor(isDark: false) }
    var accentColor: Color { accentColor(isDark: false) }

    /// 映射为 MDEditorKit 的 `EditorTheme`，严格按 `isDark` 切换对应的亮色或暗色色板。
    func editorTheme(isDark: Bool) -> EditorTheme {
        switch self {
        case .pure:
            // 官方 default-macos-39._ultheme
            if isDark {
                let fg = EditorThemeColor(red: 0.918, green: 0.918, blue: 0.918) // #EAEAEA
                return EditorTheme(
                    background: EditorThemeColor(red: 0.118, green: 0.118, blue: 0.118), // #1E1E1E
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.980, green: 0.980, blue: 0.980),
                    syntaxMarker: EditorThemeColor(red: 0.540, green: 0.540, blue: 0.565, alpha: 0.72),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.188, green: 0.820, blue: 0.345), // #30D158
                    inlineCodeBackground: EditorThemeColor(red: 0.173, green: 0.173, blue: 0.180), // #2C2C2E
                    codeBlockBackground: EditorThemeColor(red: 0.157, green: 0.157, blue: 0.165),
                    blockquote: EditorThemeColor(red: 0.540, green: 0.680, blue: 0.850),
                    link: EditorThemeColor(red: 0.000, green: 0.569, blue: 1.000), // #0091FF
                    insertionPoint: EditorThemeColor(red: 0.000, green: 0.569, blue: 1.000)
                )
            } else {
                let fg = EditorThemeColor(red: 0.149, green: 0.149, blue: 0.149) // #262626
                return EditorTheme(
                    background: EditorThemeColor(red: 1.000, green: 1.000, blue: 1.000), // #FFFFFF
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.080, green: 0.080, blue: 0.080),
                    syntaxMarker: EditorThemeColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 0.72), // #8E8E93
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.133, green: 0.545, blue: 0.255),
                    inlineCodeBackground: EditorThemeColor(red: 0.949, green: 0.949, blue: 0.957),
                    codeBlockBackground: EditorThemeColor(red: 0.961, green: 0.961, blue: 0.969),
                    blockquote: EditorThemeColor(red: 0.300, green: 0.450, blue: 0.620),
                    link: EditorThemeColor(red: 0.000, green: 0.533, blue: 1.000), // #0088FF
                    insertionPoint: EditorThemeColor(red: 0.000, green: 0.533, blue: 1.000)
                )
            }

        case .paper:
            // 官方 simple._ultheme (暖书纸 ↔ 深焙胡桃)
            if isDark {
                let fg = EditorThemeColor(red: 0.953, green: 0.945, blue: 0.929) // #F3F1ED
                return EditorTheme(
                    background: EditorThemeColor(red: 0.180, green: 0.165, blue: 0.149), // #2E2A26
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.988, green: 0.976, blue: 0.953),
                    syntaxMarker: EditorThemeColor(red: 0.660, green: 0.610, blue: 0.550, alpha: 0.72),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.875, green: 0.675, blue: 0.392),
                    inlineCodeBackground: EditorThemeColor(red: 0.243, green: 0.220, blue: 0.196),
                    codeBlockBackground: EditorThemeColor(red: 0.224, green: 0.204, blue: 0.184),
                    blockquote: EditorThemeColor(red: 0.745, green: 0.710, blue: 0.660),
                    link: EditorThemeColor(red: 0.380, green: 0.714, blue: 0.878),
                    insertionPoint: EditorThemeColor(red: 0.937, green: 0.820, blue: 0.500)
                )
            } else {
                let fg = EditorThemeColor(red: 0.247, green: 0.227, blue: 0.204) // #3F3A34
                return EditorTheme(
                    background: EditorThemeColor(red: 0.953, green: 0.945, blue: 0.929), // #F3F1ED
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.180, green: 0.160, blue: 0.140),
                    syntaxMarker: EditorThemeColor(red: 0.557, green: 0.510, blue: 0.455, alpha: 0.70),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.557, green: 0.373, blue: 0.098), // #8E5F19
                    inlineCodeBackground: EditorThemeColor(red: 0.910, green: 0.896, blue: 0.868),
                    codeBlockBackground: EditorThemeColor(red: 0.918, green: 0.906, blue: 0.880),
                    blockquote: EditorThemeColor(red: 0.455, green: 0.420, blue: 0.380),
                    link: EditorThemeColor(red: 0.271, green: 0.616, blue: 0.788), // #459DC9
                    insertionPoint: EditorThemeColor(red: 0.533, green: 0.192, blue: 0.208) // #883135
                )
            }

        case .studio:
            // 官方 freestraction._ultheme (柔灰纸 ↔ 深碳灰)
            if isDark {
                let fg = EditorThemeColor(red: 0.780, green: 0.780, blue: 0.780)
                return EditorTheme(
                    background: EditorThemeColor(red: 0.102, green: 0.102, blue: 0.102), // #1A1A1A
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.161, green: 0.714, blue: 0.878), // 青蓝标题
                    syntaxMarker: EditorThemeColor(red: 0.520, green: 0.520, blue: 0.540, alpha: 0.72),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.294, green: 0.639, blue: 0.808),
                    inlineCodeBackground: EditorThemeColor(red: 0.165, green: 0.173, blue: 0.184),
                    codeBlockBackground: EditorThemeColor(red: 0.145, green: 0.153, blue: 0.165),
                    blockquote: EditorThemeColor(red: 0.250, green: 0.670, blue: 0.820),
                    link: EditorThemeColor(red: 0.851, green: 0.369, blue: 0.643), // 紫红点缀
                    insertionPoint: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788)
                )
            } else {
                let fg = EditorThemeColor(red: 0.314, green: 0.314, blue: 0.314)
                return EditorTheme(
                    background: EditorThemeColor(red: 0.953, green: 0.953, blue: 0.953), // #F3F3F3
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788), // #009BC9
                    syntaxMarker: EditorThemeColor(red: 0.520, green: 0.540, blue: 0.560, alpha: 0.68),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.000, green: 0.451, blue: 0.659), // #0073A8
                    inlineCodeBackground: EditorThemeColor(red: 0.898, green: 0.902, blue: 0.908),
                    codeBlockBackground: EditorThemeColor(red: 0.906, green: 0.910, blue: 0.914),
                    blockquote: EditorThemeColor(red: 0.000, green: 0.520, blue: 0.690),
                    link: EditorThemeColor(red: 0.761, green: 0.192, blue: 0.518), // #C23184
                    insertionPoint: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788)
                )
            }

        case .monochrome:
            // 官方 d26-mono._ultheme (极简无干扰单色)
            if isDark {
                let fg = EditorThemeColor(red: 0.918, green: 0.918, blue: 0.918)
                return EditorTheme(
                    background: EditorThemeColor(red: 0.118, green: 0.118, blue: 0.118), // #1E1E1E
                    foreground: fg,
                    heading: EditorThemeColor(red: 1.000, green: 1.000, blue: 1.000),
                    syntaxMarker: EditorThemeColor(red: 0.520, green: 0.520, blue: 0.540, alpha: 0.65),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.840, green: 0.840, blue: 0.860),
                    inlineCodeBackground: EditorThemeColor(red: 0.173, green: 0.173, blue: 0.180),
                    codeBlockBackground: EditorThemeColor(red: 0.165, green: 0.165, blue: 0.173),
                    blockquote: EditorThemeColor(red: 0.680, green: 0.680, blue: 0.700),
                    link: EditorThemeColor(red: 0.820, green: 0.820, blue: 0.850),
                    insertionPoint: EditorThemeColor(red: 1.000, green: 1.000, blue: 1.000)
                )
            } else {
                let fg = EditorThemeColor(red: 0.149, green: 0.149, blue: 0.149)
                return EditorTheme(
                    background: EditorThemeColor(red: 0.992, green: 0.992, blue: 0.992),
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.050, green: 0.050, blue: 0.050),
                    syntaxMarker: EditorThemeColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 0.62),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.240, green: 0.240, blue: 0.260),
                    inlineCodeBackground: EditorThemeColor(red: 0.935, green: 0.935, blue: 0.940),
                    codeBlockBackground: EditorThemeColor(red: 0.945, green: 0.945, blue: 0.950),
                    blockquote: EditorThemeColor(red: 0.420, green: 0.420, blue: 0.440),
                    link: EditorThemeColor(red: 0.240, green: 0.240, blue: 0.280),
                    insertionPoint: EditorThemeColor(red: 0.080, green: 0.080, blue: 0.080)
                )
            }

        case .d22:
            // 官方 d22._ultheme (高对比纯白 ↔ OLED 纯黑)
            if isDark {
                let fg = EditorThemeColor(red: 0.918, green: 0.918, blue: 0.918) // #EAEAEA
                return EditorTheme(
                    background: EditorThemeColor(red: 0.000, green: 0.000, blue: 0.000), // #000000
                    foreground: fg,
                    heading: EditorThemeColor(red: 1.000, green: 1.000, blue: 1.000),
                    syntaxMarker: EditorThemeColor(red: 0.450, green: 0.450, blue: 0.470, alpha: 0.80),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.039, green: 0.518, blue: 1.000), // #0A84FF
                    inlineCodeBackground: EditorThemeColor(red: 0.110, green: 0.110, blue: 0.120),
                    codeBlockBackground: EditorThemeColor(red: 0.090, green: 0.090, blue: 0.100),
                    blockquote: EditorThemeColor(red: 0.353, green: 0.784, blue: 0.961), // #5AC8F5
                    link: EditorThemeColor(red: 0.353, green: 0.784, blue: 0.961),
                    insertionPoint: EditorThemeColor(red: 0.039, green: 0.518, blue: 1.000)
                )
            } else {
                let fg = EditorThemeColor(red: 0.149, green: 0.149, blue: 0.149) // #262626
                return EditorTheme(
                    background: EditorThemeColor(red: 1.000, green: 1.000, blue: 1.000), // #FFFFFF
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.000, green: 0.000, blue: 0.000),
                    syntaxMarker: EditorThemeColor(red: 0.596, green: 0.596, blue: 0.596, alpha: 0.72), // #989898
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.000, green: 0.478, blue: 1.000), // #007AFF
                    inlineCodeBackground: EditorThemeColor(red: 0.945, green: 0.955, blue: 0.975),
                    codeBlockBackground: EditorThemeColor(red: 0.955, green: 0.960, blue: 0.970),
                    blockquote: EditorThemeColor(red: 0.000, green: 0.408, blue: 0.855), // #0068DA
                    link: EditorThemeColor(red: 0.000, green: 0.408, blue: 0.855),
                    insertionPoint: EditorThemeColor(red: 0.000, green: 0.478, blue: 1.000)
                )
            }

        case .solarized:
            // 官方 solarized._ultheme (Solarized Light ↔ Solarized Dark)
            if isDark {
                let fg = EditorThemeColor(red: 0.576, green: 0.631, blue: 0.631) // #93A1A1
                return EditorTheme(
                    background: EditorThemeColor(red: 0.000, green: 0.169, blue: 0.212), // #002B36
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.933, green: 0.910, blue: 0.835),
                    syntaxMarker: EditorThemeColor(red: 0.396, green: 0.482, blue: 0.514, alpha: 0.78),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.808, green: 0.294, blue: 0.000), // #CE4B00
                    inlineCodeBackground: EditorThemeColor(red: 0.027, green: 0.212, blue: 0.259),
                    codeBlockBackground: EditorThemeColor(red: 0.027, green: 0.212, blue: 0.259),
                    blockquote: EditorThemeColor(red: 0.722, green: 0.537, blue: 0.000), // #B88900
                    link: EditorThemeColor(red: 0.008, green: 0.541, blue: 0.831), // #028AD4
                    insertionPoint: EditorThemeColor(red: 0.933, green: 0.910, blue: 0.835)
                )
            } else {
                let fg = EditorThemeColor(red: 0.333, green: 0.431, blue: 0.459) // #556E75
                return EditorTheme(
                    background: EditorThemeColor(red: 0.996, green: 0.969, blue: 0.886), // #FEF7E2
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.027, green: 0.212, blue: 0.259),
                    syntaxMarker: EditorThemeColor(red: 0.573, green: 0.573, blue: 0.573, alpha: 0.72),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.808, green: 0.294, blue: 0.000), // #CE4B00
                    inlineCodeBackground: EditorThemeColor(red: 0.933, green: 0.910, blue: 0.835),
                    codeBlockBackground: EditorThemeColor(red: 0.933, green: 0.910, blue: 0.835),
                    blockquote: EditorThemeColor(red: 0.008, green: 0.541, blue: 0.831),
                    link: EditorThemeColor(red: 0.008, green: 0.541, blue: 0.831), // #028AD4
                    insertionPoint: EditorThemeColor(red: 0.333, green: 0.431, blue: 0.459)
                )
            }

        case .yosemite:
            // 官方 yosemite._ultheme
            if isDark {
                let fg = EditorThemeColor(red: 0.816, green: 0.816, blue: 0.816) // #D0D0D0
                return EditorTheme(
                    background: EditorThemeColor(red: 0.157, green: 0.157, blue: 0.157), // #282828
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788), // #009BC9
                    syntaxMarker: EditorThemeColor(red: 0.520, green: 0.520, blue: 0.540, alpha: 0.72),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.294, green: 0.639, blue: 0.808),
                    inlineCodeBackground: EditorThemeColor(red: 0.210, green: 0.210, blue: 0.220),
                    codeBlockBackground: EditorThemeColor(red: 0.196, green: 0.196, blue: 0.205),
                    blockquote: EditorThemeColor(red: 0.161, green: 0.714, blue: 0.878),
                    link: EditorThemeColor(red: 0.851, green: 0.369, blue: 0.643),
                    insertionPoint: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788)
                )
            } else {
                let fg = EditorThemeColor(red: 0.137, green: 0.137, blue: 0.137) // #232323
                return EditorTheme(
                    background: EditorThemeColor(red: 1.000, green: 1.000, blue: 1.000), // #FFFFFF
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788), // #009BC9
                    syntaxMarker: EditorThemeColor(red: 0.540, green: 0.540, blue: 0.560, alpha: 0.68),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.000, green: 0.451, blue: 0.659), // #0073A8
                    inlineCodeBackground: EditorThemeColor(red: 0.941, green: 0.953, blue: 0.965),
                    codeBlockBackground: EditorThemeColor(red: 0.949, green: 0.957, blue: 0.965),
                    blockquote: EditorThemeColor(red: 0.000, green: 0.533, blue: 0.710),
                    link: EditorThemeColor(red: 0.761, green: 0.192, blue: 0.518), // #C23184
                    insertionPoint: EditorThemeColor(red: 0.000, green: 0.608, blue: 0.788)
                )
            }

        case .nord:
            // Nord Snow Storm (Light) ↔ Nord Polar Night (Dark)
            if isDark {
                let fg = EditorThemeColor(red: 0.847, green: 0.871, blue: 0.914) // #D8DEE9
                return EditorTheme(
                    background: EditorThemeColor(red: 0.180, green: 0.204, blue: 0.251), // #2E3440
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.925, green: 0.937, blue: 0.957), // #ECEFF4
                    syntaxMarker: EditorThemeColor(red: 0.498, green: 0.549, blue: 0.620, alpha: 0.75),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.561, green: 0.737, blue: 0.733), // #8FBCBB
                    inlineCodeBackground: EditorThemeColor(red: 0.231, green: 0.259, blue: 0.322), // #3B4252
                    codeBlockBackground: EditorThemeColor(red: 0.231, green: 0.259, blue: 0.322),
                    blockquote: EditorThemeColor(red: 0.670, green: 0.720, blue: 0.780),
                    link: EditorThemeColor(red: 0.533, green: 0.753, blue: 0.816), // #88C0D0
                    insertionPoint: EditorThemeColor(red: 0.533, green: 0.753, blue: 0.816)
                )
            } else {
                let fg = EditorThemeColor(red: 0.180, green: 0.204, blue: 0.251) // #2E3440
                return EditorTheme(
                    background: EditorThemeColor(red: 0.925, green: 0.937, blue: 0.957), // #ECEFF4
                    foreground: fg,
                    heading: EditorThemeColor(red: 0.120, green: 0.145, blue: 0.188),
                    syntaxMarker: EditorThemeColor(red: 0.460, green: 0.510, blue: 0.580, alpha: 0.70),
                    emphasis: fg,
                    inlineCode: EditorThemeColor(red: 0.298, green: 0.478, blue: 0.569),
                    inlineCodeBackground: EditorThemeColor(red: 0.847, green: 0.871, blue: 0.914), // #D8DEE9
                    codeBlockBackground: EditorThemeColor(red: 0.875, green: 0.894, blue: 0.925),
                    blockquote: EditorThemeColor(red: 0.298, green: 0.337, blue: 0.416), // #4C566A
                    link: EditorThemeColor(red: 0.369, green: 0.506, blue: 0.675), // #5E81AC
                    insertionPoint: EditorThemeColor(red: 0.369, green: 0.506, blue: 0.675)
                )
            }
        }
    }

    /// 便捷方法：根据 `AppTheme` 解析亮暗并构建编辑器主题。
    @MainActor
    func editorTheme(for appTheme: AppTheme) -> EditorTheme {
        editorTheme(isDark: appTheme.resolvedIsDark())
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
