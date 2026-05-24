//
//  MarkdownSettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import MDEditorKit
import SwiftUI

// MARK: - Ulysses 风格语法元素描述

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
    .init(title: "Table", example: "| a | b |\\n|---|---|", category: .extended),
    .init(title: "Footnote", example: "text[^1]", category: .extended),
]

// MARK: - 设置视图

struct MarkdownSettingsView: View {
    @AppStorage("markdownTheme") private var selectedTheme: MarkdownTheme = .pure
    @AppStorage("markdownStandard") private var selectedStandard: MarkdownStandard = .markdownXL

    // Ulysses 风格语法特性开关（影响 HTML 渲染层；编辑器侧由 MDEditor 包决定能否响应）
    @AppStorage("markdownFeatureStrikethrough") private var featureStrikethrough: Bool = true
    @AppStorage("markdownFeatureTaskList") private var featureTaskList: Bool = true
    @AppStorage("markdownFeatureTable") private var featureTable: Bool = true
    @AppStorage("markdownFeatureFootnote") private var featureFootnote: Bool = false

    // 标记可见性（Ulysses: Show/Hide Markup）
    @AppStorage("markdownShowMarkup") private var showMarkup: Bool = true

    // 折叠状态
    @State private var showMarkupReference: Bool = false

    private let themeColumns = [
        GridItem(.adaptive(minimum: 80, maximum: 100))
    ]

    var body: some View {
        Form {
            // MARK: 排版标准
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(LocalizedStringKey("Syntax Standard:"), selection: $selectedStandard) {
                        ForEach(MarkdownStandard.allCases) { standard in
                            Text(standard.displayName).tag(standard)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(
                        LocalizedStringKey(
                            "Markdown XL keeps headings at body size. Standard scales them.")
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text(LocalizedStringKey("Formatting"))
            }

            // MARK: 配色方案
            Section {
                VStack(alignment: .leading, spacing: 15) {
                    Text(
                        LocalizedStringKey(
                            "Select a color scheme for syntax highlighting and preview.")
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    LazyVGrid(columns: themeColumns, spacing: 15) {
                        ForEach(MarkdownTheme.allCases) { theme in
                            VStack(spacing: 8) {
                                ThemePreviewCircle(
                                    theme: theme, isSelected: selectedTheme == theme
                                )
                                .onTapGesture {
                                    selectedTheme = theme
                                }

                                Text(theme.displayName)
                                    .font(.system(size: 10))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(height: 25, alignment: .top)
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
                        "Theme drives the editor canvas, preview background and exported PDF/RTF."
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

struct ThemePreviewCircle: View {
    let theme: MarkdownTheme
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.paperColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(theme.isDark ? .white : .black)
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .padding(3)
        .background(
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
