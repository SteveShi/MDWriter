//
//  MarkdownRenderService.swift
//  MDWriter
//
//  出版级 Markdown → HTML 渲染服务：
//  - 100% 离线原生 LaTeX 数学公式渲染（通过 MDEditorKit.MathRenderer 输出高清 PNG Data URI + 精确基线对齐）
//  - 本地图片自动转为 Base64 Data URI 内嵌，彻底解决 WebKit PDF/HTML 导出跨源拦截导致图片裂图的问题
//  - 支持 6 套 Ulysses 风格出版排版样式（Swiss / Academic / Manuscript / Editorial / Business / Editor Theme）
//  - 完整 @page 与 @media print 规则，保留背景色、表格排版与智能分页防断行
//

import AppKit
import Foundation
import MDEditorKit

@MainActor
struct MDWMarkdownRenderer {

    private struct StylePalette {
        let bg: String
        let text: String
        let heading: String
        let muted: String
        let link: String
        let codeBg: String
        let codeText: String
        let border: String
        let tableHeaderBg: String
        let quoteBg: String
        let markBg: String
        let isDark: Bool
    }

    // MARK: - Public Rendering API

    func renderHTML(
        from markdown: String,
        style: ExportStyle = .swiss,
        theme: MarkdownTheme = .pure,
        paperSize: ExportPaperSize = .a4,
        includeScripts: Bool = true
    ) -> String {
        let palette = resolvePalette(style: style, theme: theme)
        let preprocessed = preprocessExtendedSyntax(markdown)
        var body = MarkdownConverter.toHTML(preprocessed, imageResolver: Self.resolveImageAsDataURI)
        body = renderOfflineMathInHTML(body, textColorHex: palette.text)

        let css = buildDocumentCSS(style: style, palette: palette, paperSize: paperSize)
        let scripts = includeScripts ? mermaidScript(isDark: palette.isDark) : ""

        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                \(css)
                \(scripts)
            </head>
            <body>
                <article class="document-body style-\(style.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))">
                    \(body)
                </article>
            </body>
            </html>
            """
    }

    func renderCardHTML(
        from markdown: String,
        title: String,
        style: ExportStyle = .swiss,
        theme: MarkdownTheme = .pure
    ) -> String {
        let palette = resolvePalette(style: style, theme: theme)
        let preprocessed = preprocessExtendedSyntax(markdown)
        var body = MarkdownConverter.toHTML(preprocessed, imageResolver: Self.resolveImageAsDataURI)
        body = renderOfflineMathInHTML(body, textColorHex: palette.text)

        let css = buildDocumentCSS(style: style, palette: palette, paperSize: .a4)
        let displayTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled" : htmlEscape(title)
        let wordCount = markdown.split(whereSeparator: \.isWhitespace).count
        let charCount = markdown.count
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: Date())

        let outerBg = palette.isDark ? "#121417" : "#eceff4"

        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                \(css)
                <style>
                    html, body {
                        background-color: \(outerBg) !important;
                        padding: 36px 24px !important;
                        margin: 0 !important;
                        max-width: none !important;
                        display: flex;
                        justify-content: center;
                    }
                    .social-card {
                        width: 660px;
                        background-color: \(palette.bg);
                        color: \(palette.text);
                        border-radius: 16px;
                        box-shadow: 0 16px 38px rgba(0, 0, 0, \(palette.isDark ? "0.45" : "0.09"));
                        border: 1px solid \(palette.border);
                        overflow: hidden;
                        box-sizing: border-box;
                    }
                    .card-header {
                        padding: 30px 36px 20px 36px;
                        border-bottom: 1px solid \(palette.border);
                    }
                    .card-title {
                        font-size: 25px;
                        font-weight: 700;
                        margin: 0 0 8px 0;
                        line-height: 1.3;
                        color: \(palette.heading);
                    }
                    .card-meta {
                        font-size: 12px;
                        color: \(palette.muted);
                        display: flex;
                        gap: 16px;
                    }
                    .card-body {
                        padding: 24px 36px 32px 36px;
                    }
                    .card-body .document-body {
                        padding: 0;
                        margin: 0;
                        max-width: none;
                    }
                    .card-footer {
                        padding: 15px 36px;
                        border-top: 1px solid \(palette.border);
                        background-color: \(palette.isDark ? "rgba(255,255,255,0.03)" : "rgba(0,0,0,0.02)");
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        font-size: 12px;
                        color: \(palette.muted);
                    }
                    .brand-tag {
                        font-weight: 600;
                        letter-spacing: 0.4px;
                    }
                </style>
            </head>
            <body>
                <div class="social-card">
                    <div class="card-header">
                        <div class="card-title">\(displayTitle)</div>
                        <div class="card-meta">
                            <span>\(dateString)</span>
                            <span>\(wordCount) words · \(charCount) chars</span>
                        </div>
                    </div>
                    <div class="card-body">
                        <article class="document-body style-\(style.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))">
                            \(body)
                        </article>
                    </div>
                    <div class="card-footer">
                        <span class="brand-tag">MDWriter</span>
                        <span>\(style.rawValue)</span>
                    </div>
                </div>
            </body>
            </html>
            """
    }

    // MARK: - Extended Markdown Preprocessing (==highlight== & [[WikiLink]])

    private func preprocessExtendedSyntax(_ markdown: String) -> String {
        // 按围栏代码块切分，避免污染代码块内部字符
        let lines = markdown.components(separatedBy: "\n")
        var output: [String] = []
        var inFence = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                output.append(line)
                continue
            }
            if inFence {
                output.append(line)
                continue
            }
            output.append(transformInlineExtensionsOutsideCode(line))
        }
        return output.joined(separator: "\n")
    }

    private func transformInlineExtensionsOutsideCode(_ line: String) -> String {
        // 保护行内代码 `...` 与行内公式 $...$
        guard let protectRegex = try? NSRegularExpression(
            pattern: #"(`[^`\n]+`|\$\$[^$\n]+\$\$|\$[^$\n]+\$)"#
        ) else {
            return applyExtensions(to: line)
        }

        let ns = line as NSString
        let matches = protectRegex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty {
            return applyExtensions(to: line)
        }

        var result = ""
        var cursor = 0
        for match in matches {
            if match.range.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result += applyExtensions(to: plain)
            }
            result += ns.substring(with: match.range)
            cursor = NSMaxRange(match.range)
        }
        if cursor < ns.length {
            result += applyExtensions(to: ns.substring(from: cursor))
        }
        return result
    }

    private func applyExtensions(to segment: String) -> String {
        var text = segment

        // ==highlight== → <mark>highlight</mark>
        if let markRegex = try? NSRegularExpression(pattern: #"==([^=\n]+?)=="#) {
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            text = markRegex.stringByReplacingMatches(
                in: text, options: [], range: range, withTemplate: "<mark>$1</mark>"
            )
        }

        // [[Target|Alias]] 或 [[Target]] → <span class="wikilink">Alias</span>
        if let wikiRegex = try? NSRegularExpression(pattern: #"(?<!!)\[\[([^\[\]\n]+)\]\]"#) {
            let ns = text as NSString
            let matches = wikiRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                var mutable = text
                for match in matches.reversed() {
                    let inner = ns.substring(with: match.range(at: 1))
                    let display: String
                    if let pipeIdx = inner.firstIndex(of: "|") {
                        display = String(inner[inner.index(after: pipeIdx)...])
                            .trimmingCharacters(in: .whitespaces)
                    } else {
                        display = inner.trimmingCharacters(in: .whitespaces)
                    }
                    let html = "<span class=\"wikilink\">\(htmlEscape(display))</span>"
                    if let swiftRange = Range(match.range, in: mutable) {
                        mutable.replaceSubrange(swiftRange, with: html)
                    }
                }
                text = mutable
            }
        }

        return text
    }

    // MARK: - 100% Offline LaTeX Math Rendering (SwiftMath -> Crisp Data URI PNG)

    private func renderOfflineMathInHTML(_ html: String, textColorHex: String) -> String {
        let color = nsColor(fromHex: textColorHex) ?? NSColor.labelColor
        var output = html

        // 1. 块级公式：<div class="math-block">$$...$$</div>
        output = replaceMathPattern(
            in: output,
            pattern: #"(?s)<div class="math-block">\$\$(.+?)\$\$</div>"#,
            isDisplay: true,
            color: color
        )

        // 2. 行内公式：<span class="math">\(...\)</span>
        output = replaceMathPattern(
            in: output,
            pattern: #"(?s)<span class="math">\\\((.+?)\\\)</span>"#,
            isDisplay: false,
            color: color
        )

        // 3. 兜底匹配未被 MarkdownParser 拆出的裸 $$...$$ 段落
        output = replaceMathPattern(
            in: output,
            pattern: #"(?s)<p>\$\$(.+?)\$\$</p>"#,
            isDisplay: true,
            color: color
        )

        return output
    }

    private func replaceMathPattern(
        in html: String,
        pattern: String,
        isDisplay: Bool,
        color: NSColor
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return html }

        var result = html
        for match in matches.reversed() {
            let escapedLatex = ns.substring(with: match.range(at: 1))
            let latex = htmlUnescape(escapedLatex).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !latex.isEmpty else { continue }

            // 使用 2x 字号渲染后按 0.5x CSS 尺寸展示，保证 PDF 与 Retina 屏幕矢量级锐利
            let cssFontSize: CGFloat = isDisplay ? 15.0 : 13.5
            let renderScale: CGFloat = 2.0
            if let rendered = MathRenderer.shared.render(
                latex: latex,
                fontSize: cssFontSize * renderScale,
                textColor: color,
                isDisplay: isDisplay
            ),
               let pngBase64 = pngDataURIFromNSImage(rendered.image)
            {
                let cssWidth = rendered.image.size.width / renderScale
                let cssHeight = rendered.image.size.height / renderScale
                let cssDescent = rendered.descent / renderScale

                let replacement: String
                if isDisplay {
                    replacement = """
                        <div class="math-block"><img class="math-display-img" src="\(pngBase64)" alt="\(htmlEscape(latex))" style="width:\(String(format: "%.1f", cssWidth))px;height:\(String(format: "%.1f", cssHeight))px;" /></div>
                        """
                } else {
                    replacement = """
                        <img class="math-inline-img" src="\(pngBase64)" alt="\(htmlEscape(latex))" style="width:\(String(format: "%.1f", cssWidth))px;height:\(String(format: "%.1f", cssHeight))px;vertical-align:\(String(format: "%.1f", -cssDescent))px;" />
                        """
                }

                if let swiftRange = Range(match.range, in: result) {
                    result.replaceSubrange(swiftRange, with: replacement)
                }
            }
        }
        return result
    }

    private func pngDataURIFromNSImage(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        return "data:image/png;base64,\(png.base64EncodedString())"
    }

    // MARK: - Local Image Data URI Embedding (Fixes Broken Images in PDF/HTML)

    nonisolated private static func resolveImageAsDataURI(_ source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://")
            || trimmed.lowercased().hasPrefix("https://")
            || trimmed.lowercased().hasPrefix("data:")
        {
            return trimmed
        }

        var cleanPath = trimmed
        if cleanPath.hasPrefix("file://") {
            cleanPath = String(cleanPath.dropFirst(7))
        }
        let decodedPath = cleanPath.removingPercentEncoding ?? cleanPath

        var candidates: [URL] = [URL(fileURLWithPath: decodedPath)]
        if !decodedPath.hasPrefix("/"),
           let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            candidates.append(docs.appendingPathComponent("Images").appendingPathComponent(decodedPath))
            candidates.append(docs.appendingPathComponent(decodedPath))
        }

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url) {
                let ext = url.pathExtension.lowercased()
                let mime: String
                switch ext {
                case "jpg", "jpeg": mime = "image/jpeg"
                case "gif": mime = "image/gif"
                case "webp": mime = "image/webp"
                case "svg": mime = "image/svg+xml"
                default: mime = "image/png"
                }
                return "data:\(mime);base64,\(data.base64EncodedString())"
            }
        }

        return trimmed
    }

    // MARK: - Palette Resolution

    private func resolvePalette(style: ExportStyle, theme: MarkdownTheme) -> StylePalette {
        switch style {
        case .swiss:
            return StylePalette(
                bg: "#ffffff", text: "#1f2328", heading: "#0f1419", muted: "#59636e",
                link: "#0969da", codeBg: "#f5f7f9", codeText: "#c7254e", border: "#e2e6ea",
                tableHeaderBg: "#f6f8fa", quoteBg: "#f8f9fb", markBg: "#fff3a8", isDark: false
            )
        case .academic:
            return StylePalette(
                bg: "#ffffff", text: "#1c1c1c", heading: "#111111", muted: "#555555",
                link: "#1a4e8a", codeBg: "#f6f5f2", codeText: "#2c2c2c", border: "#d4d0c8",
                tableHeaderBg: "#f4f2ec", quoteBg: "transparent", markBg: "#fcf0b3", isDark: false
            )
        case .manuscript:
            return StylePalette(
                bg: "#ffffff", text: "#222222", heading: "#111111", muted: "#666666",
                link: "#222222", codeBg: "#f4f4f4", codeText: "#222222", border: "#cccccc",
                tableHeaderBg: "#f2f2f2", quoteBg: "transparent", markBg: "#fff3b0", isDark: false
            )
        case .editorial:
            return StylePalette(
                bg: "#fcfbf8", text: "#2d2926", heading: "#1a1715", muted: "#6e655d",
                link: "#8f3d2e", codeBg: "#f2efe8", codeText: "#7a2e22", border: "#e2dcd2",
                tableHeaderBg: "#f4f0e8", quoteBg: "#f7f4ed", markBg: "#f9e79f", isDark: false
            )
        case .business:
            return StylePalette(
                bg: "#ffffff", text: "#24292f", heading: "#1b365d", muted: "#5c6873",
                link: "#1d5fa7", codeBg: "#f3f5f8", codeText: "#1b365d", border: "#d8dee4",
                tableHeaderBg: "#eef2f7", quoteBg: "#f4f7fb", markBg: "#fef08a", isDark: false
            )
        case .matchEditor:
            return editorThemePalette(for: theme)
        }
    }

    private func editorThemePalette(for theme: MarkdownTheme) -> StylePalette {
        switch theme {
        case .pure:
            return StylePalette(
                bg: "#ffffff", text: "#222222", heading: "#111111", muted: "#666666",
                link: "#007aff", codeBg: "#f5f7f9", codeText: "#c7254e", border: "#e5e7eb",
                tableHeaderBg: "#f6f8fa", quoteBg: "#f9fafb", markBg: "#fff3a8", isDark: false
            )
        case .paper:
            return StylePalette(
                bg: "#f3f1ed", text: "#3f3a34", heading: "#2e2924", muted: "#7a7167",
                link: "#457ec9", codeBg: "#e8e4dc", codeText: "#aa4f32", border: "#dcd6cc",
                tableHeaderBg: "#eae6de", quoteBg: "#ece8e0", markBg: "#efe79a", isDark: false
            )
        case .studio:
            return StylePalette(
                bg: "#f3f3f3", text: "#4a4a4a", heading: "#262626", muted: "#767676",
                link: "#0073a8", codeBg: "#e6e7e9", codeText: "#c43836", border: "#d8d8d8",
                tableHeaderBg: "#eaeaea", quoteBg: "#ebebeb", markBg: "#fff1a8", isDark: false
            )
        case .monochrome:
            return StylePalette(
                bg: "#fcfcfc", text: "#262626", heading: "#111111", muted: "#6e6e73",
                link: "#3a3a3c", codeBg: "#efefef", codeText: "#262626", border: "#dedede",
                tableHeaderBg: "#f2f2f2", quoteBg: "#f6f6f6", markBg: "#e5e5ea", isDark: false
            )
        case .espresso:
            return StylePalette(
                bg: "#2a2622", text: "#efece6", heading: "#faf6ee", muted: "#a69c90",
                link: "#74b5d5", codeBg: "#3a342e", codeText: "#e6b075", border: "#4a423b",
                tableHeaderBg: "#36302a", quoteBg: "#332d27", markBg: "#5c4d26", isDark: true
            )
        case .solarizedLight:
            return StylePalette(
                bg: "#fdf6e3", text: "#586e75", heading: "#073642", muted: "#839496",
                link: "#268bd2", codeBg: "#eee8d5", codeText: "#dc322f", border: "#dcd5c1",
                tableHeaderBg: "#eee8d5", quoteBg: "#f5eed9", markBg: "#eee19a", isDark: false
            )
        case .solarizedDark:
            return StylePalette(
                bg: "#002b36", text: "#93a1a1", heading: "#eee8d5", muted: "#657b83",
                link: "#268bd2", codeBg: "#073642", codeText: "#cb4b16", border: "#1b4956",
                tableHeaderBg: "#073642", quoteBg: "#06323d", markBg: "#4a4419", isDark: true
            )
        case .github:
            return StylePalette(
                bg: "#f6f8fa", text: "#24292e", heading: "#11161b", muted: "#6a737d",
                link: "#0366d6", codeBg: "#eaeef2", codeText: "#cf222e", border: "#d0d7de",
                tableHeaderBg: "#eaeef2", quoteBg: "#f0f3f6", markBg: "#fff8c5", isDark: false
            )
        case .dracula:
            return StylePalette(
                bg: "#282a36", text: "#f8f8f2", heading: "#ff79c6", muted: "#9aa0c2",
                link: "#8be9fd", codeBg: "#383a4a", codeText: "#50fa7b", border: "#44475a",
                tableHeaderBg: "#343746", quoteBg: "#313341", markBg: "#574f24", isDark: true
            )
        case .nord:
            return StylePalette(
                bg: "#2e3440", text: "#d8dee9", heading: "#eceff4", muted: "#9aa5b8",
                link: "#88c0d0", codeBg: "#3b4252", codeText: "#8fbcbb", border: "#4c566a",
                tableHeaderBg: "#3b4252", quoteBg: "#353c4a", markBg: "#574c2c", isDark: true
            )
        case .monokai:
            return StylePalette(
                bg: "#272822", text: "#f8f8f2", heading: "#f92672", muted: "#a6a695",
                link: "#66d9ef", codeBg: "#383930", codeText: "#a6e22e", border: "#49483e",
                tableHeaderBg: "#36372f", quoteBg: "#30312a", markBg: "#595324", isDark: true
            )
        case .nightOwl:
            return StylePalette(
                bg: "#011627", text: "#d6deeb", heading: "#ecc48d", muted: "#7e97ac",
                link: "#82aaff", codeBg: "#0b2942", codeText: "#7fdbca", border: "#1d3b53",
                tableHeaderBg: "#0b2942", quoteBg: "#072036", markBg: "#3b3a17", isDark: true
            )
        }
    }

    // MARK: - Publication Typography & Print CSS

    private func buildDocumentCSS(
        style: ExportStyle,
        palette: StylePalette,
        paperSize: ExportPaperSize
    ) -> String {
        let defaults = UserDefaults.standard
        let featureStrikethrough = defaults.object(forKey: "markdownFeatureStrikethrough") as? Bool ?? true
        let featureTaskList = defaults.object(forKey: "markdownFeatureTaskList") as? Bool ?? true
        let featureTable = defaults.object(forKey: "markdownFeatureTable") as? Bool ?? true
        let featureFootnote = defaults.object(forKey: "markdownFeatureFootnote") as? Bool ?? false

        var featureOverrides: [String] = []
        if !featureStrikethrough { featureOverrides.append("del, s { text-decoration: none; }") }
        if !featureTaskList { featureOverrides.append("input[type=\"checkbox\"] { display: none; }") }
        if !featureTable { featureOverrides.append("table { display: none; }") }
        if !featureFootnote { featureOverrides.append(".footnote-ref, .footnote-backref, .footnotes { display: none; }") }

        let styleSpecificCSS: String
        switch style {
        case .swiss, .matchEditor:
            styleSpecificCSS = """
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", "PingFang SC", "Hiragino Sans GB", sans-serif;
                    font-size: 10.5pt;
                    line-height: 1.72;
                }
                h1 { font-size: 2.0em; font-weight: 700; letter-spacing: -0.02em; margin-top: 0.4em; padding-bottom: 0.35em; border-bottom: 1.5px solid \(palette.border); }
                h2 { font-size: 1.45em; font-weight: 650; letter-spacing: -0.015em; margin-top: 1.8em; padding-bottom: 0.25em; border-bottom: 1px solid \(palette.border); }
                h3 { font-size: 1.18em; font-weight: 600; margin-top: 1.4em; }
                blockquote { border-left: 3px solid \(palette.link); background: \(palette.quoteBg); padding: 10px 16px; border-radius: 0 6px 6px 0; }
                """
        case .academic:
            styleSpecificCSS = """
                body {
                    font-family: Georgia, "Times New Roman", "Songti SC", "STSong", serif;
                    font-size: 11pt;
                    line-height: 1.82;
                }
                h1 { font-size: 1.85em; font-weight: 700; text-align: center; margin: 0.3em 0 1.2em 0; padding-bottom: 0.5em; border-bottom: 1px solid \(palette.border); }
                h2 { font-size: 1.35em; font-weight: 700; margin-top: 1.8em; }
                h3 { font-size: 1.12em; font-weight: 600; font-style: italic; margin-top: 1.4em; }
                p { text-align: justify; hyphens: auto; }
                blockquote { border-left: 2px solid \(palette.border); padding: 4px 18px; font-style: italic; color: \(palette.muted); }
                table { border-top: 2px solid \(palette.heading); border-bottom: 2px solid \(palette.heading); }
                table th { border-bottom: 1px solid \(palette.heading); border-left: none; border-right: none; background: transparent; }
                table td { border-left: none; border-right: none; border-top: 1px solid \(palette.border); }
                """
        case .manuscript:
            styleSpecificCSS = """
                body {
                    font-family: "Courier Prime", "SF Mono", Menlo, "STFangsong", monospace;
                    font-size: 10.5pt;
                    line-height: 1.95;
                }
                h1 { font-size: 1.45em; font-weight: 700; text-align: center; text-transform: uppercase; letter-spacing: 0.08em; margin: 1.2em 0 1.4em 0; }
                h2 { font-size: 1.2em; font-weight: 700; margin-top: 1.8em; }
                h3 { font-size: 1.05em; font-weight: 700; text-decoration: underline; margin-top: 1.4em; }
                p { text-indent: 2em; margin-bottom: 0.8em; }
                h1 + p, h2 + p, h3 + p, blockquote p, li p { text-indent: 0; }
                blockquote { border-left: 2px dashed \(palette.border); padding: 4px 18px; }
                """
        case .editorial:
            styleSpecificCSS = """
                body {
                    font-family: Charter, "Iowan Old Style", Georgia, "Songti SC", serif;
                    font-size: 11pt;
                    line-height: 1.78;
                }
                h1 { font-size: 2.2em; font-weight: 700; letter-spacing: -0.025em; line-height: 1.2; margin: 0.2em 0 0.8em 0; }
                h2 { font-size: 1.42em; font-weight: 700; margin-top: 1.8em; color: \(palette.link); }
                h3 { font-size: 1.12em; font-weight: 600; letter-spacing: 0.03em; text-transform: uppercase; margin-top: 1.5em; }
                blockquote { border-left: 3px solid \(palette.link); background: \(palette.quoteBg); padding: 12px 20px; font-style: italic; font-size: 1.05em; }
                """
        case .business:
            styleSpecificCSS = """
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
                    font-size: 10pt;
                    line-height: 1.65;
                }
                h1 { font-size: 1.9em; font-weight: 700; color: \(palette.heading); border-bottom: 2.5px solid \(palette.heading); padding-bottom: 0.35em; margin-bottom: 0.9em; }
                h2 { font-size: 1.32em; font-weight: 650; color: \(palette.heading); margin-top: 1.6em; padding-bottom: 0.2em; border-bottom: 1px solid \(palette.border); }
                h3 { font-size: 1.1em; font-weight: 600; color: \(palette.link); margin-top: 1.3em; }
                blockquote { border-left: 4px solid \(palette.heading); background: \(palette.quoteBg); padding: 10px 16px; border-radius: 0 4px 4px 0; }
                table th { background-color: \(palette.heading); color: #ffffff; border-color: \(palette.heading); }
                """
        }

        return """
            <style>
                @page {
                    size: \(paperSize.cssPageSize);
                    margin: 22mm 20mm 22mm 20mm;
                }
                * {
                    box-sizing: border-box;
                    -webkit-print-color-adjust: exact !important;
                    print-color-adjust: exact !important;
                }
                html {
                    background-color: \(palette.bg);
                }
                body {
                    margin: 0;
                    padding: 0;
                    color: \(palette.text);
                    background-color: \(palette.bg);
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                .document-body {
                    max-width: 720px;
                    margin: 0 auto;
                    padding: 36px 40px;
                }
                @media print {
                    html, body {
                        background-color: \(palette.bg) !important;
                        margin: 0 !important;
                        padding: 0 !important;
                    }
                    .document-body {
                        max-width: none !important;
                        margin: 0 !important;
                        padding: 0 !important;
                    }
                    h1, h2, h3, h4, h5, h6 {
                        break-after: avoid-page;
                        page-break-after: avoid;
                    }
                    pre, blockquote, table, figure, img, .math-block {
                        break-inside: avoid;
                        page-break-inside: avoid;
                    }
                    p {
                        orphans: 3;
                        widows: 3;
                    }
                }
                h1, h2, h3, h4, h5, h6 {
                    color: \(palette.heading);
                    line-height: 1.3;
                    margin-bottom: 0.6em;
                }
                h4 { font-size: 1.05em; font-weight: 600; margin-top: 1.2em; }
                h5 { font-size: 0.95em; font-weight: 600; margin-top: 1.1em; }
                h6 { font-size: 0.9em; font-weight: 600; color: \(palette.muted); margin-top: 1.0em; }
                p {
                    margin-top: 0;
                    margin-bottom: 1em;
                }
                a {
                    color: \(palette.link);
                    text-decoration: none;
                    border-bottom: 1px solid rgba(128, 128, 128, 0.25);
                }
                strong { font-weight: 700; color: \(palette.heading); }
                em { font-style: italic; }
                del { text-decoration: line-through; opacity: 0.72; }
                mark {
                    background-color: \(palette.markBg);
                    color: inherit;
                    padding: 0.08em 0.28em;
                    border-radius: 3px;
                }
                .wikilink {
                    color: \(palette.link);
                    font-weight: 500;
                    border-bottom: 1px dashed \(palette.link);
                }
                code {
                    font-family: "SF Mono", "SFMono-Regular", Menlo, Consolas, monospace;
                    background-color: \(palette.codeBg);
                    color: \(palette.codeText);
                    padding: 0.16em 0.38em;
                    border-radius: 4px;
                    font-size: 0.88em;
                }
                pre {
                    background-color: \(palette.codeBg);
                    border: 1px solid \(palette.border);
                    padding: 14px 16px;
                    border-radius: 6px;
                    overflow-x: auto;
                    line-height: 1.5;
                    margin: 1.1em 0;
                }
                pre code {
                    background: transparent;
                    color: \(palette.text);
                    padding: 0;
                    font-size: 0.86em;
                    white-space: pre-wrap;
                    word-break: break-word;
                }
                blockquote {
                    margin: 1.1em 0;
                    color: \(palette.muted);
                }
                blockquote > :last-child { margin-bottom: 0; }
                ul, ol {
                    padding-left: 1.8em;
                    margin-top: 0;
                    margin-bottom: 1em;
                }
                li { margin-bottom: 0.32em; }
                li > p { margin-bottom: 0.35em; }
                ul.task-list {
                    list-style-type: none;
                    padding-left: 0.2em;
                }
                ul.task-list input[type="checkbox"] {
                    margin-right: 7px;
                    vertical-align: middle;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 1.2em 0;
                    font-size: 0.94em;
                }
                table th, table td {
                    border: 1px solid \(palette.border);
                    padding: 7px 11px;
                    text-align: left;
                }
                table th {
                    background-color: \(palette.tableHeaderBg);
                    font-weight: 600;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 4px;
                }
                .math-block {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    margin: 1.1em 0;
                    padding: 6px 0;
                    overflow-x: auto;
                }
                .math-display-img, .math-inline-img {
                    display: inline-block;
                    max-width: 100%;
                    border-radius: 0;
                    background: transparent;
                }
                hr {
                    height: 1px;
                    border: 0;
                    background-color: \(palette.border);
                    margin: 1.8em 0;
                }
                \(styleSpecificCSS)
                \(featureOverrides.joined(separator: "\n"))
            </style>
            """
    }

    private func mermaidScript(isDark: Bool) -> String {
        """
        <script type="module">
            const codeBlocks = document.querySelectorAll('pre code.language-mermaid, pre.mermaid, code.language-mermaid');
            if (codeBlocks.length > 0) {
                import('https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs')
                    .then(async ({ default: mermaid }) => {
                        mermaid.initialize({ startOnLoad: false, theme: '\(isDark ? "dark" : "default")' });
                        codeBlocks.forEach((el) => {
                            const pre = el.closest('pre') || el;
                            const div = document.createElement('div');
                            div.className = 'mermaid';
                            div.textContent = el.textContent;
                            pre.parentNode.replaceChild(div, pre);
                        });
                        await mermaid.run();
                    })
                    .catch(() => {});
            }
        </script>
        """
    }

    // MARK: - String & Color Helpers

    private func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func htmlUnescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private func nsColor(fromHex hex: String) -> NSColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
