//
//  TypographySettings.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import AppKit
import Combine
import SwiftUI

// 1. 定义纯数据的配置结构体 (Value Type)
struct TypographyConfiguration: Equatable {
    var fontName: String
    var fontSize: Double
    var lineHeightMultiple: Double
    var paragraphSpacing: Double
    var firstLineIndent: Double
    var contentWidth: Double

    // 辅助方法：生成 NSFont
    var nsFont: NSFont {
        switch fontName {
        case "System":
            return .systemFont(ofSize: fontSize)
        case "System Serif":
            if let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
                .withDesign(.serif)
            {
                return NSFont(descriptor: descriptor, size: fontSize)
                    ?? .systemFont(ofSize: fontSize)
            }
            return .systemFont(ofSize: fontSize)
        case "Monospaced":
            return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        default:
            return NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        }
    }
}

// 2. 设置管理器 (ObservableObject)
class TypographySettings: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @AppStorage("editorFontName") var fontName: String = "System Serif"
    @AppStorage("editorFontSize") var fontSize: Double = 17.0
    @AppStorage("lineHeightMultiple") var lineHeightMultiple: Double = 1.6
    @AppStorage("paragraphSpacing") var paragraphSpacing: Double = 18.0
    @AppStorage("firstLineIndent") var firstLineIndent: Double = 0.0
    @AppStorage("contentWidth") var contentWidth: Double = 700.0

    init() {
        // 监听 UserDefaults 变化，确保跨窗口同步时触发 UI 刷新
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // 生成当前配置快照
    var configuration: TypographyConfiguration {
        TypographyConfiguration(
            fontName: fontName,
            fontSize: fontSize,
            lineHeightMultiple: lineHeightMultiple,
            paragraphSpacing: paragraphSpacing,
            firstLineIndent: firstLineIndent,
            contentWidth: contentWidth
        )
    }
}

// 3. 设置面板 UI
struct TypographyPanel: View {
    @ObservedObject var settings: TypographySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Typography")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()

            // 字体选择
            Grid(alignment: .leading, verticalSpacing: 10) {
                GridRow {
                    Text("Font")
                    Picker("", selection: $settings.fontName) {
                        // 预设组
                        Section("Presets") {
                            Text("System UI").tag("System")
                            Text("System Serif").tag("System Serif")
                            Text("Monospaced").tag("Monospaced")
                        }

                        // 系统字体组
                        Section("Installed Fonts") {
                            ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) {
                                family in
                                // 简单的去重逻辑：如果预设里有了就不显示（可选），这里直接全显示也无妨
                                Text(family).tag(family)
                                    .font(.custom(family, size: 12))  // 让用户能预览字体样式
                            }
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                GridRow {
                    Text("Size")
                    HStack {
                        Slider(value: $settings.fontSize, in: 12...32, step: 1)
                        Text("\(Int(settings.fontSize))")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // 排版细节
            Grid(alignment: .leading, verticalSpacing: 10) {
                GridRow {
                    Label("Line Height", systemImage: "arrow.up.and.down.text.horizontal")
                        .labelStyle(.iconOnly)
                        .help(Text("Line Height"))
                    HStack {
                        Slider(value: $settings.lineHeightMultiple, in: 1.0...3.0, step: 0.1)
                        Text(String(format: "%.1f", settings.lineHeightMultiple))
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    Label("Para Spacing", systemImage: "paragraphsign")
                        .labelStyle(.iconOnly)
                        .help(Text("Paragraph Spacing"))
                    HStack {
                        Slider(value: $settings.paragraphSpacing, in: 0...50, step: 2)
                        Text("\(Int(settings.paragraphSpacing))")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    Label("First Line", systemImage: "arrow.forward.to.line")
                        .labelStyle(.iconOnly)
                        .help(Text("First Line Indent"))
                    HStack {
                        Slider(value: $settings.firstLineIndent, in: 0...50, step: 5)
                        Text("\(Int(settings.firstLineIndent))")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    Label("Width", systemImage: "arrow.left.and.right.square")
                        .labelStyle(.iconOnly)
                        .help(Text("Editor Width"))
                    HStack {
                        Slider(value: $settings.contentWidth, in: 400...1200, step: 50)
                        Text("\(Int(settings.contentWidth))")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 260)
    }
}
