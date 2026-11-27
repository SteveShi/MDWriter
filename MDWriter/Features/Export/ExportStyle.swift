//
//  ExportStyle.swift
//  MDWriter
//
//  出版级导出排版风格（写作配色与导出样式解耦设计）：
//  写作时可用任意护眼/暗色主题，导出 PDF/HTML/长图时独立选用出版排版风格。
//

import CoreGraphics
import Foundation
import SwiftUI

/// 出版级导出样式（独立于编辑器配色方案）。
enum ExportStyle: String, CaseIterable, Identifiable {
    case swiss = "Swiss"
    case academic = "Academic"
    case manuscript = "Manuscript"
    case editorial = "Editorial"
    case business = "Business"
    case matchEditor = "Editor Theme"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .swiss: return LocalizedStringKey("Swiss")
        case .academic: return LocalizedStringKey("Academic")
        case .manuscript: return LocalizedStringKey("Manuscript")
        case .editorial: return LocalizedStringKey("Editorial")
        case .business: return LocalizedStringKey("Business")
        case .matchEditor: return LocalizedStringKey("Editor Theme")
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .swiss: return LocalizedStringKey("Clean geometric sans-serif")
        case .academic: return LocalizedStringKey("Classic serif with formal typography")
        case .manuscript: return LocalizedStringKey("Double-spaced editorial draft")
        case .editorial: return LocalizedStringKey("Warm magazine-grade serif")
        case .business: return LocalizedStringKey("Structured report with crisp tables")
        case .matchEditor: return LocalizedStringKey("Matches your active editor color scheme")
        }
    }

    var iconName: String {
        switch self {
        case .swiss: return "textformat"
        case .academic: return "graduationcap"
        case .manuscript: return "doc.plaintext"
        case .editorial: return "book.pages"
        case .business: return "briefcase"
        case .matchEditor: return "paintpalette"
        }
    }
}

/// PDF 导出纸张规格。
enum ExportPaperSize: String, CaseIterable, Identifiable {
    case a4 = "A4"
    case usLetter = "US Letter"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .a4: return LocalizedStringKey("A4")
        case .usLetter: return LocalizedStringKey("US Letter")
        }
    }

    /// 纸张尺寸（点 / pt，72 dpi）。
    var sizeInPoints: CGSize {
        switch self {
        case .a4: return CGSize(width: 595.28, height: 841.89)
        case .usLetter: return CGSize(width: 612.0, height: 792.0)
        }
    }

    /// CSS `@page size` 值。
    var cssPageSize: String {
        switch self {
        case .a4: return "A4"
        case .usLetter: return "letter"
        }
    }
}
