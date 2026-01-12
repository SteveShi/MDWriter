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
        case .light: return Color(red: 0.97, green: 0.97, blue: 0.96)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.11)
        }
    }
}

extension AppTheme {
    func resolvePaperColor(scheme: ColorScheme) -> Color {
        return paperColor
    }
}
