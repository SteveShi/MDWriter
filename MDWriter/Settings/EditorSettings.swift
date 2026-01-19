//
//  EditorSettings.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import Combine
import SwiftUI

enum MarkdownStandard: String, CaseIterable, Identifiable {
    case markdownXL = "Markdown XL"
    case standard = "Standard"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .markdownXL: return LocalizedStringKey("Markdown XL")
        case .standard: return LocalizedStringKey("Standard")
        }
    }
}

// 纯数据结构，用于传递给 EditorView
struct EditorConfiguration: Equatable {
    var fontName: String
    var lineHeightMultiple: CGFloat
    var contentWidth: CGFloat
    var paragraphSpacing: CGFloat
    var firstLineIndent: CGFloat
    var typewriterMode: Bool
    var markdownStandard: MarkdownStandard

    // 固定基准字号为 17
    static let baseFontSize: CGFloat = 17.0

    // 使用支持中文的字体
    var platformFont: PlatformFont {
        let size = Self.baseFontSize

        // 优先使用用户选择的字体
        if fontName != "System" {
            #if os(macOS)
            if let font = NSFont(name: fontName, size: size) {
                return font
            }
            #else
            if let font = UIFont(name: fontName, size: size) {
                return font
            }
            #endif
        }

        // 默认使用苹方字体（中文优化）
        let fontNameForSystem = "PingFang SC"
        #if os(macOS)
        if let pingFang = NSFont(name: fontNameForSystem, size: size) {
            return pingFang
        }
        return .systemFont(ofSize: size)
        #else
        if let pingFang = UIFont(name: fontNameForSystem, size: size) {
            return pingFang
        }
        return .systemFont(ofSize: size)
        #endif
    }
}

class EditorSettings: ObservableObject {
    static let shared = EditorSettings()

    // 字体
    @AppStorage("editorFontName") var fontName: String = "System" {
        didSet { notifyChange() }
    }
    // 取消 fontSize 设置

    @AppStorage("editorLineHeight") var lineHeightMultiple: Double = 1.7 {
        didSet { notifyChange() }
    }

    // 布局
    @AppStorage("editorContentWidth") var contentWidth: Double = 750.0 {
        didSet { notifyChange() }
    }
    @AppStorage("editorParagraphSpacing") var paragraphSpacing: Double = 18.0 {
        didSet { notifyChange() }
    }
    @AppStorage("editorFirstLineIndent") var firstLineIndent: Double = 0.0 {
        didSet { notifyChange() }
    }

    // 行为
    @AppStorage("editorTypewriterMode") var typewriterMode: Bool = true {
        didSet { notifyChange() }
    }

    // Markdown
    @AppStorage("markdownStandard") var markdownStandard: MarkdownStandard = .markdownXL {
        didSet { notifyChange() }
    }

    // 对外发布的配置快照
    @Published var configuration: EditorConfiguration

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.configuration = EditorConfiguration(
            fontName: "PingFang SC",
            lineHeightMultiple: 1.7,
            contentWidth: 750.0,
            paragraphSpacing: 18.0,
            firstLineIndent: 0.0,
            typewriterMode: true,
            markdownStandard: .markdownXL
        )

        // Initial sync
        self.updateConfiguration()

        // Observe external UserDefaults changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateConfiguration()
                }
            }
            .store(in: &cancellables)
    }

    private func notifyChange() {
        updateConfiguration()
    }

    private func updateConfiguration() {
        let newConfig = EditorConfiguration(
            fontName: fontName,
            lineHeightMultiple: CGFloat(lineHeightMultiple),
            contentWidth: CGFloat(contentWidth),
            paragraphSpacing: CGFloat(paragraphSpacing),
            firstLineIndent: CGFloat(firstLineIndent),
            typewriterMode: typewriterMode,
            markdownStandard: markdownStandard
        )

        if self.configuration != newConfig {
            self.configuration = newConfig
            self.objectWillChange.send()
        }
    }
}
