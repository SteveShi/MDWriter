//
//  MarkdownSettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import MDEditorKit
import SwiftUI

// MARK: - Markdown 语法元素描述

/// 单个 Markdown 元素的描述，用于「Markup Reference」清单。
private struct MarkupElement: Identifiable, Sendable {
    let id = UUID()
    let title: String     // 本地化 key（仅 ASCII，由 Localizable.xcstrings 提供翻译）
    let example: String   // 纯 ASCII 语法示例，作为代码字面量展示，无需本地化
    let category: Category

    enum Category: String, CaseIterable, Identifiable, Sendable {
        case block
        case inline
        case list
        case extended

        var id: String { rawValue }

        var displayName: LocalizedStringKey {
            switch self {
            case .block: return LocalizedStringKey("Block Elements")
            case .inline: return LocalizedStringKey("Inline Elements")
            case .list: return LocalizedStringKey("Lists & Tasks")
            case .extended: return LocalizedStringKey("Extended Syntax")
            }
        }
    }
}

/// 当前应用所支持/计划支持的 Markdown 元素清单。
private let markupCatalog: [MarkupElement] = [
    .init(title: "Heading 1", example: "# Heading", category: .block),
    .init(title: "Heading 2", example: "## Heading", category: .block),
    .init(title: "Heading 3", example: "### Heading", category: .block),
    .init(title: "Paragraph", example: "Just plain text.", category: .block),
    .init(title: "Blockquote", example: "> quoted text", category: .block),
    .init(title: "Code Block", example: "```swift\\ncode\\n```", category: .block),
    .init(title: "Horizontal Rule", example: "---", category: .block),

    .init(title: "Bold", example: "**bold**", category: .inline),
    .init(title: "Italic", example: "*italic*", category: .inline),
    .init(title: "Inline Code", example: "`code`", category: .inline),
    .init(title: "Link", example: "[text](https://)", category: .inline),
    .init(title: "Image", example: "![alt](path)", category: .inline),

    .init(title: "Bullet List", example: "- item", category: .list),
    .init(title: "Ordered List", example: "1. item", category: .list),
    .init(title: "Task List", example: "- [ ] todo", category: .list),

    .init(title: "Strikethrough", example: "~~struck~~", category: .extended),
    .init(title: "Inline Math", example: "$E = mc^2$", category: .extended),
    .init(title: "Display Math", example: "$$\\sum_{i=1}^n i$$", category: .extended),
    .init(title: "WikiLink", example: "[[Note Title]]", category: .extended),
    .init(title: "Table", example: "| a | b |\\n|---|---|", category: .extended),
    .init(title: "Footnote", example: "text[^1]", category: .extended),
]

// MARK: - 设置视图

struct MarkdownSettingsView: View {
    @AppStorage("markdownTheme") private var selectedThemeRaw: String = MarkdownTheme.pure.rawValue

    private var selectedTheme: MarkdownTheme {
        MarkdownTheme.fromStorage(selectedThemeRaw)
    }

    // Markdown 语法特性开关（影响 HTML 渲染层；编辑器侧由 MDEditor 包决定能否响应）
    @AppStorage("markdownFeatureStrikethrough") private var featureStrikethrough: Bool = true
    @AppStorage("markdownFeatureTaskList") private var featureTaskList: Bool = true
    @AppStorage("markdownFeatureTable") private var featureTable: Bool = true
    @AppStorage("markdownFeatureFootnote") private var featureFootnote: Bool = false

    // 标记可见性（Show/Hide Markup）
    @AppStorage("markdownShowMarkup") private var showMarkup: Bool = true

    // 默认导出出版风格与纸张尺寸（独立于编辑器配色）
    @AppStorage("exportStyle") private var defaultExportStyleRaw: String = ExportStyle.swiss.rawValue
    @AppStorage("exportPaperSize") private var defaultPaperSizeRaw: String = ExportPaperSize.a4.rawValue

    // 折叠状态
    @State private var showMarkupReference: Bool = false

    private let themeColumns = [
        GridItem(.adaptive(minimum: 102, maximum: 120), spacing: 14)
    ]

    var body: some View {
        Form {

            // MARK: 配色方案（双模式亮/暗色板预览卡片）
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        LocalizedStringKey(
                            "Every built-in color scheme includes calibrated Light and Dark palettes that adapt automatically with your Appearance setting.")
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    LazyVGrid(columns: themeColumns, spacing: 14) {
                        ForEach(MarkdownTheme.allCases) { theme in
                            VStack(spacing: 6) {
                                ThemePreviewSwatch(
                                    theme: theme,
                                    isSelected: selectedTheme == theme
                                )
                                .onTapGesture {
                                    selectedThemeRaw = theme.rawValue
                                }

                                Text(theme.displayName)
                                    .font(.system(size: 11, weight: selectedTheme == theme ? .semibold : .regular))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .foregroundColor(
                                        selectedTheme == theme ? .primary : .secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(LocalizedStringKey("Color Scheme"))
            } footer: {
                Text(
                    LocalizedStringKey(
                        "Theme drives the editor canvas, quick action bar, and 'Editor Theme' export mode."
                    )
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            // MARK: 默认导出排版风格
            Section {
                Picker(LocalizedStringKey("Export Style"), selection: $defaultExportStyleRaw) {
                    ForEach(ExportStyle.allCases) { style in
                        Label(style.displayName, systemImage: style.iconName)
                            .tag(style.rawValue)
                    }
                }
                Picker(LocalizedStringKey("Paper Size"), selection: $defaultPaperSizeRaw) {
                    ForEach(ExportPaperSize.allCases) { paper in
                        Text(paper.displayName).tag(paper.rawValue)
                    }
                }
            } header: {
                Text(LocalizedStringKey("Export Typography"))
            } footer: {
                Text(
                    LocalizedStringKey(
                        "Export typography is decoupled from editor color schemes and applies to PDF, HTML, and Social Card exports."
                    )
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            // MARK: 标记可见性 & 语法特性
            Section {
                Toggle(LocalizedStringKey("Show Markup Characters"), isOn: $showMarkup)
                Toggle(LocalizedStringKey("Strikethrough"), isOn: $featureStrikethrough)
                Toggle(LocalizedStringKey("Task Lists"), isOn: $featureTaskList)
                Toggle(LocalizedStringKey("Tables"), isOn: $featureTable)
                Toggle(LocalizedStringKey("Footnotes"), isOn: $featureFootnote)
            } header: {
                Text(LocalizedStringKey("Markup Features"))
            } footer: {
                Text(
                    LocalizedStringKey(
                        "Toggles apply to HTML/PDF/RTF rendering. Editor visibility follows MDEditor capabilities."
                    )
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            // MARK: Markdown 语法参考表
            Section {
                DisclosureGroup(isExpanded: $showMarkupReference) {
                    ForEach(MarkupElement.Category.allCases) { category in
                        let items = markupCatalog.filter { $0.category == category }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 6)

                                ForEach(items) { item in
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(LocalizedStringKey(item.title))
                                            .frame(width: 140, alignment: .leading)
                                        Text(item.example)
                                            .font(
                                                .system(.caption, design: .monospaced)
                                            )
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label(
                        LocalizedStringKey("Markup Reference"),
                        systemImage: "text.book.closed"
                    )
                }
            } header: {
                Text(LocalizedStringKey("Syntax Cheat Sheet"))
            }
        }
        .formStyle(.grouped)
    }
}

/// 双色板预览卡片：左侧展示亮色纸面与排版，右侧展示暗色纸面与排版。
struct ThemePreviewSwatch: View {
    let theme: MarkdownTheme
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                halfPreview(isDark: false)
                halfPreview(isDark: true)
            }
            .frame(width: 96, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white, Color.accentColor)
                    .offset(x: 4, y: -4)
            }
        }
        .padding(2.5)
        .overlay(
            RoundedRectangle(cornerRadius: 10.5, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private func halfPreview(isDark: Bool) -> some View {
        let bg = theme.paperColor(isDark: isDark)
        let fg = theme.textColor(isDark: isDark)
        let accent = theme.accentColor(isDark: isDark)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text("#")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(fg.opacity(0.85))
                    .frame(width: 22, height: 3.5)
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(fg.opacity(0.45))
                .frame(width: 32, height: 2.5)
            RoundedRectangle(cornerRadius: 1)
                .fill(fg.opacity(0.35))
                .frame(width: 26, height: 2.5)
            RoundedRectangle(cornerRadius: 1)
                .fill(accent.opacity(0.75))
                .frame(width: 18, height: 2.5)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}
