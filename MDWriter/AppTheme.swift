//
//  AppTheme.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/12.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var paperColor: Color {
        switch self {
        case .light: return Color(red: 0.97, green: 0.97, blue: 0.96)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.11)
        case .system:
            return Color(
                NSColor(name: nil) { appearance in
                    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                        return NSColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.0)
                    } else {
                        return NSColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
                    }
                })
        }
    }
}

extension AppTheme {
    func resolvePaperColor(scheme: ColorScheme) -> Color {
        if self == .system {
            return scheme == .dark
                ? Color(red: 0.11, green: 0.11, blue: 0.11)
                : Color(red: 0.97, green: 0.97, blue: 0.96)
        }
        return paperColor
    }
}
