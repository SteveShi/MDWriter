//
//  InlineEntityPopover.swift
//  MDWriter
//
//  内联实体编辑浮层：
//  支持编辑链接、图片以及带实时矢量预览的 LaTeX 数学公式（行内 / 块级切换）。
//

import AppKit
import MDEditorKit
import SwiftUI

struct InlineEntityPopover: View {
    let entity: EditorEntityInfo
    @ObservedObject var controller: EditorController
    var onDismiss: () -> Void

    @State private var primaryText: String = ""
    @State private var secondaryText: String = ""
    @State private var isDisplayMath: Bool = false
    @FocusState private var isPrimaryFocused: Bool

    private static let mathSnippets: [(label: String, latex: String)] = [
        ("a/b", #"\frac{a}{b}"#),
        ("√x", #"\sqrt{x}"#),
        ("xⁿ", #"x^{n}"#),
        ("xᵢ", #"x_{i}"#),
        ("∑", #"\sum_{i=1}^{n}"#),
        ("∫", #"\int_{a}^{b}"#),
        ("α", #"\alpha"#),
        ("→", #"\rightarrow"#),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Label(headerTitle, systemImage: headerIcon)
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            switch entity.kind {
            case .link:
                linkEditorBody
            case .image:
                imageEditorBody
            case .inlineMath, .displayMath:
                mathEditorBody
            }

            Divider().opacity(0.4)

            // 底部按钮区
            HStack {
                if entity.kind == .link,
                   let url = URL(string: secondaryText.trimmingCharacters(in: .whitespacesAndNewlines)),
                   url.scheme != nil
                {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label(LocalizedStringKey("Open URL"), systemImage: "arrow.up.right.square")
                            .font(.system(size: 11.5))
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button(LocalizedStringKey("Cancel")) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(LocalizedStringKey("Apply")) {
                    commitChanges()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: isMathEntity ? 400 : 340)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 6)
        .onAppear {
            primaryText = entity.primaryText
            secondaryText = entity.secondaryText
            isDisplayMath = (entity.kind == .displayMath)
            isPrimaryFocused = true
        }
    }

    private var isMathEntity: Bool {
        entity.kind == .inlineMath || entity.kind == .displayMath
    }

    private var headerTitle: LocalizedStringKey {
        switch entity.kind {
        case .link: return LocalizedStringKey("Edit Link")
        case .image: return LocalizedStringKey("Edit Image")
        case .inlineMath, .displayMath: return LocalizedStringKey("Edit LaTeX Formula")
        }
    }

    private var headerIcon: String {
        switch entity.kind {
        case .link: return "link"
        case .image: return "photo"
        case .inlineMath, .displayMath: return "function"
        }
    }

    // MARK: - Link Body

    private var linkEditorBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Display Text"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(LocalizedStringKey("Link title"), text: $primaryText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isPrimaryFocused)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("URL"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://", text: $secondaryText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitChanges() }
            }
        }
    }

    // MARK: - Image Body

    private var imageEditorBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Alt Text"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(LocalizedStringKey("Image description"), text: $primaryText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isPrimaryFocused)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Image Path or URL"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(LocalizedStringKey("image.png or https://"), text: $secondaryText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitChanges() }
            }
        }
    }

    // MARK: - LaTeX Math Body (with Live Native SwiftMath Preview)

    private var mathEditorBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(LocalizedStringKey("Display Mode"), selection: $isDisplayMath) {
                Text(LocalizedStringKey("Inline ($...$)")).tag(false)
                Text(LocalizedStringKey("Display ($$...$$)")).tag(true)
            }
            .pickerStyle(.segmented)

            // 实时原生矢量预览区
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))

                if let rendered = MathRenderer.shared.render(
                    latex: primaryText,
                    fontSize: isDisplayMath ? 18 : 16,
                    textColor: NSColor.labelColor,
                    isDisplay: isDisplayMath
                ) {
                    Image(nsImage: rendered.image)
                        .interpolation(.high)
                        .padding(10)
                } else if primaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(LocalizedStringKey("Enter LaTeX expression..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label(LocalizedStringKey("Invalid LaTeX syntax"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 110)

            // LaTeX 源码输入
            TextEditor(text: $primaryText)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 68)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .focused($isPrimaryFocused)

            // 常用符号快捷片
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.mathSnippets, id: \.latex) { snippet in
                        Button {
                            primaryText += snippet.latex
                        } label: {
                            Text(snippet.label)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Commit

    private func commitChanges() {
        let newSource: String
        switch entity.kind {
        case .link:
            newSource = "[\(primaryText)](\(secondaryText))"
        case .image:
            newSource = "![\(primaryText)](\(secondaryText))"
        case .inlineMath, .displayMath:
            let cleaned = primaryText.trimmingCharacters(in: .whitespacesAndNewlines)
            if isDisplayMath {
                newSource = "$$\n\(cleaned)\n$$"
            } else {
                newSource = "$\(cleaned)$"
            }
        }
        controller.applyEntityEdit(entity: entity, newSource: newSource)
    }
}
