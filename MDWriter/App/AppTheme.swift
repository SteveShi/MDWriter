//
//  AppTheme.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import AppKit
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .system: return LocalizedStringKey("System")
        case .light: return LocalizedStringKey("Light")
        case .dark: return LocalizedStringKey("Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// 根据显式设置或当前 SwiftUI 环境解析最终是否处于暗色模式。
    func isDark(in environmentScheme: ColorScheme) -> Bool {
        switch self {
        case .system: return environmentScheme == .dark
        case .light: return false
        case .dark: return true
        }
    }

    /// 供 AppKit / 非视图层（如 EditorSettings、ExportService）实时解析当前外观是否为暗色。
    @MainActor
    func resolvedIsDark() -> Bool {
        switch self {
        case .light: return false
        case .dark: return true
        case .system:
            let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    func paperColor(isDark: Bool) -> Color {
        isDark
            ? Color(red: 0.118, green: 0.118, blue: 0.118) // #1E1E1E (官方 Ulysses 默认暗色纸面)
            : Color(red: 1.000, green: 1.000, blue: 1.000) // #FFFFFF (官方 Ulysses 默认亮色纸面)
    }

    var paperColor: Color {
        switch self {
        case .dark: return paperColor(isDark: true)
        case .light: return paperColor(isDark: false)
        case .system: return Color(nsColor: .textBackgroundColor)
        }
    }

    var accentColor: Color {
        switch self {
        case .light: return Color(red: 0.000, green: 0.533, blue: 1.000)
        case .dark: return Color(red: 0.000, green: 0.569, blue: 1.000)
        case .system: return .accentColor
        }
    }

    var secondaryBackgroundColor: Color {
        switch self {
        case .light: return Color(red: 0.961, green: 0.961, blue: 0.969)
        case .dark: return Color(red: 0.145, green: 0.145, blue: 0.153)
        case .system: return Color(nsColor: .underPageBackgroundColor)
        }
    }
}

extension AppTheme {
    var material: Material {
        switch self {
        case .light: return .thinMaterial
        case .dark: return .ultraThinMaterial
        case .system: return .regularMaterial
        }
    }
}
