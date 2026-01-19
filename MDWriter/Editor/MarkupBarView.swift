//
//  MarkupBarView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI

struct MarkupBarView: View {
    @ObservedObject var controller: EditorController
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            // Headings
            Menu {
                Button(LocalizedStringKey("Heading 1")) { controller.insertMarkup("# ") }
                Button(LocalizedStringKey("Heading 2")) { controller.insertMarkup("## ") }
                Button(LocalizedStringKey("Heading 3")) { controller.insertMarkup("### ") }
                Button(LocalizedStringKey("Heading 4")) { controller.insertMarkup("#### ") }
            } label: {
                MarkupBarButton(icon: "number", label: "H")
            }

            Divider().frame(height: 20)

            // Text Formatting
            MarkupBarButton(icon: "bold", label: nil) {
                controller.toggleBold()
            }
            MarkupBarButton(icon: "italic", label: nil) {
                controller.toggleItalic()
            }
            MarkupBarButton(icon: "strikethrough", label: nil) {
                controller.toggleStrikethrough()
            }

            Divider().frame(height: 20)

            // Links & Media
            MarkupBarButton(icon: "link", label: nil) {
                controller.insertLinkMarkup()
            }
            MarkupBarButton(icon: "photo", label: nil) {
                controller.insertImageMarkup()
            }

            Divider().frame(height: 20)

            // Structure
            MarkupBarButton(icon: "text.quote", label: nil) {
                controller.insertMarkup("> ")
            }
            MarkupBarButton(icon: "chevron.left.forwardslash.chevron.right", label: nil) {
                controller.toggleCodeBlock()
            }

            Menu {
                Button(LocalizedStringKey("Unordered List")) { controller.insertMarkup("- ") }
                Button(LocalizedStringKey("Ordered List")) { controller.insertMarkup("1. ") }
                Button(LocalizedStringKey("Task List")) { controller.insertMarkup("- [ ] ") }
            } label: {
                MarkupBarButton(icon: "list.bullet", label: nil)
            }

            Divider().frame(height: 20)

            // Horizontal Rule
            MarkupBarButton(icon: "minus", label: nil) {
                controller.insertMarkup("\n---\n")
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - iOS Specific Markup Bar

struct IOSMarkupBar: View {
    @ObservedObject var controller: EditorController
    
    var body: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    // Ulysses 风格：直接插入 Markdown 符号
                    MarkupSymbolButton(symbol: "#", action: { controller.insertMarkup("#") })
                    MarkupSymbolButton(symbol: "*", action: { controller.toggleItalic() })
                    MarkupSymbolButton(symbol: "**", action: { controller.toggleBold() })
                    MarkupSymbolButton(symbol: ">", action: { controller.insertMarkup("> ") })
                    MarkupSymbolButton(symbol: "-", action: { controller.insertMarkup("- ") })
                    MarkupSymbolButton(symbol: "[ ]", action: { controller.insertMarkup("- [ ] ") })
                    MarkupSymbolButton(symbol: "!", icon: "photo", action: { controller.insertImageMarkup() })
                    MarkupSymbolButton(symbol: "[]", icon: "link", action: { controller.insertLinkMarkup() })
                    MarkupSymbolButton(symbol: "``", icon: "chevron.left.forwardslash.chevron.right", action: { controller.toggleCodeBlock() })
                }
                .padding(.horizontal, 15)
            }
            
            Divider().frame(height: 24)
            
            // 收起键盘按钮
            Button(action: {
                #if os(iOS)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
            }) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .medium))
                    .padding(.horizontal, 12)
            }
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

struct MarkupSymbolButton: View {
    let symbol: String
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Text(symbol)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
            }
            .frame(minWidth: 24)
            .foregroundColor(.primary.opacity(0.7))
        }
    }
}

// MARK: - Markup Bar Button

struct MarkupBarButton: View {
    let icon: String
    let label: String?
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                if let label = label {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary.opacity(0.8))
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

#Preview {
    MarkupBarView(controller: EditorController())
        .frame(width: 600)
}
