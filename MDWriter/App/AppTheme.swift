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
    case sepia = "Sepia"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .sepia: return .light
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .sepia: return "book"
        }
    }

    var paperColor: Color {
        switch self {
        case .light: return Color(red: 0.98, green: 0.98, blue: 0.97)
        case .dark: return Color(red: 0.08, green: 0.08, blue: 0.09)
        case .sepia: return Color(red: 0.96, green: 0.92, blue: 0.85)
        }
    }

    var accentColor: Color {
        switch self {
        case .light: return .blue
        case .dark: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .sepia: return Color(red: 0.7, green: 0.4, blue: 0.2)
        }
    }

    var secondaryBackgroundColor: Color {
        switch self {
        case .light: return Color(white: 0.95)
        case .dark: return Color(white: 0.15)
        case .sepia: return Color(red: 0.92, green: 0.88, blue: 0.80)
        }
    }
}

extension AppTheme {
    var material: Material {
        switch self {
        case .light: return .thinMaterial
        case .dark: return .ultraThinMaterial
        case .sepia: return .regularMaterial
        }
    }

    func resolvePaperColor(scheme: ColorScheme) -> Color {
        return paperColor
    }
}
