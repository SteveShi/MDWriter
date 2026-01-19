//
//  PlatformAdaptation.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/19.
//

import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
typealias PlatformImage = NSImage
typealias PlatformViewRepresentable = NSViewRepresentable
typealias PlatformFontDescriptor = NSFontDescriptor
#else
import UIKit
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
typealias PlatformImage = UIImage
typealias PlatformViewRepresentable = UIViewRepresentable
typealias PlatformFontDescriptor = UIFontDescriptor
#endif

extension PlatformFont {
    nonisolated func withTraits(_ traits: PlatformFontDescriptor.SymbolicTraits) -> PlatformFont {
        #if os(macOS)
        let descriptor = self.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: 0) ?? self
        #else
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
        #endif
    }
    
    nonisolated var bold: PlatformFont {
        #if os(macOS)
        return NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask)
        #else
        return withTraits(.traitBold)
        #endif
    }
    
    nonisolated var italic: PlatformFont {
        #if os(macOS)
        return NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
        #else
        return withTraits(.traitItalic)
        #endif
    }
}

// 扩展方便在 SwiftUI 中使用
extension Color {
    static var platformBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
}