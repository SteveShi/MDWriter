//
//  MarkdownSettingsView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI

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
}

struct MarkdownSettingsView: View {
    @AppStorage("markdownTheme") private var selectedTheme: MarkdownTheme = .pure
    @AppStorage("markdownStandard") private var selectedStandard: MarkdownStandard = .markdownXL
    
    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100))
    ]
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(LocalizedStringKey("Syntax Standard:"), selection: $selectedStandard) {
                        ForEach(MarkdownStandard.allCases) { standard in
                            Text(standard.displayName).tag(standard)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(LocalizedStringKey("Markdown XL keeps headings at body size. Standard scales them."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text(LocalizedStringKey("Formatting"))
            }

            Section {
                VStack(alignment: .leading, spacing: 15) {
                    Text(LocalizedStringKey("Select a color scheme for syntax highlighting and preview."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(MarkdownTheme.allCases) { theme in
                            VStack(spacing: 8) {
                                ThemePreviewCircle(theme: theme, isSelected: selectedTheme == theme)
                                    .onTapGesture {
                                        selectedTheme = theme
                                    }
                                
                                Text(theme.displayName)
                                    .font(.system(size: 10))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(height: 25, alignment: .top)
                                    .foregroundColor(selectedTheme == theme ? .primary : .secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(LocalizedStringKey("Color Scheme"))
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
                .fill(themeColor)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(theme == .pure || theme == .solarizedLight || theme == .github ? .black : .white)
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .padding(3)
        .background(
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    var themeColor: Color {
        switch theme {
        case .pure: return .white
        case .solarizedLight: return Color(red: 0.99, green: 0.96, blue: 0.89)
        case .solarizedDark: return Color(red: 0.0, green: 0.17, blue: 0.21)
        case .github: return Color(red: 0.96, green: 0.97, blue: 0.98)
        case .dracula: return Color(red: 0.16, green: 0.16, blue: 0.18)
        case .nord: return Color(red: 0.18, green: 0.20, blue: 0.25)
        case .monokai: return Color(red: 0.15, green: 0.15, blue: 0.14)
        case .nightOwl: return Color(red: 0.01, green: 0.09, blue: 0.15)
        }
    }
}