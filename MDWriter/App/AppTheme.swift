//
//  AppTheme.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var paperColor: Color {
        switch self {
        case .light: return Color(red: 0.98, green: 0.98, blue: 0.97)
        case .dark: return Color(red: 0.08, green: 0.08, blue: 0.09)
        }
    }

    var accentColor: Color {
        switch self {
        case .light: return .blue
        case .dark: return Color(red: 0.4, green: 0.6, blue: 1.0)
        }
    }

    var secondaryBackgroundColor: Color {
        switch self {
        case .light: return Color(white: 0.95)
        case .dark: return Color(white: 0.15)
        }
    }
}

extension AppTheme {
    var material: Material {
        switch self {
        case .light: return .thinMaterial
        case .dark: return .ultraThinMaterial
        }
    }

    func resolvePaperColor(scheme: ColorScheme) -> Color {
        return paperColor
    }
}
