//
//  MarkdownRenderService.swift
//  MDWriter
//
//  Markdown → HTML renderer used by Export (PDF/RTF) and preview surfaces.
//

import Foundation
import MDEditorKit

struct MDWMarkdownRenderer {
    func renderHTML(from markdown: String, theme: MarkdownTheme) -> String {
        let body = MarkdownConverter.toHTML(markdown, imageResolver: resolveImageSource)
        return wrapHTML(body: body, theme: theme)
    }

    func renderCardHTML(from markdown: String, title: String, theme: MarkdownTheme) -> String {
        let body = MarkdownConverter.toHTML(markdown, imageResolver: resolveImageSource)
        let colors = themeColorHex(for: theme)
        let css = themeCSS(for: theme)
        let scripts = mathematicalAndDiagramScripts(isDark: theme.isDark)

        let displayTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
        let wordCount = markdown.split(whereSeparator: \.isWhitespace).count
        let charCount = markdown.count
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: Date())

        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                \(css)
                \(scripts)
                <style>
                    body {
                        background-color: \(theme.isDark ? "#121417" : "#eef1f5");
                        padding: 36px 20px;
                        margin: 0;
                        display: flex;
                        justify-content: center;
                    }
                    .social-card {
                        width: 660px;
                        background-color: \(colors.bg);
                        color: \(colors.text);
                        border-radius: 16px;
                        box-shadow: 0 16px 36px rgba(0, 0, 0, \(theme.isDark ? "0.45" : "0.08"));
                        border: 1px solid \(colors.border);
                        overflow: hidden;
                        box-sizing: border-box;
                    }
                    .card-header {
                        padding: 32px 36px 20px 36px;
                        border-bottom: 1px solid \(colors.border);
                    }
                    .card-title {
                        font-size: 26px;
                        font-weight: 700;
                        margin: 0 0 10px 0;
                        line-height: 1.3;
                        color: \(colors.text);
                    }
                    .card-meta {
                        font-size: 12px;
                        color: \(colors.text);
                        opacity: 0.65;
                        display: flex;
                        gap: 16px;
                    }
                    .card-body {
                        padding: 24px 36px 32px 36px;
                    }
                    .card-footer {
                        padding: 16px 36px;
                        border-top: 1px solid \(colors.border);
                        background-color: \(theme.isDark ? "rgba(255,255,255,0.03)" : "rgba(0,0,0,0.02)");
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        font-size: 12px;
                        color: \(colors.text);
                        opacity: 0.7;
                    }
                    .brand-tag {
                        font-weight: 600;
                        letter-spacing: 0.5px;
                    }
                </style>
            </head>
            <body>
                <div class="social-card">
                    <div class="card-header">
                        <div class="card-title">\(displayTitle)</div>
                        <div class="card-meta">
                            <span>📅 \(dateString)</span>
                            <span>📝 \(wordCount) words · \(charCount) chars</span>
                        </div>
                    </div>
                    <div class="card-body">
                        \(body)
                    </div>
                    <div class="card-footer">
                        <span class="brand-tag">MDWriter</span>
                        <span>Quiet Native Markdown</span>
                    </div>
                </div>
            </body>
            </html>
            """
    }

    private func themeColorHex(for theme: MarkdownTheme) -> (bg: String, text: String, link: String, codeBg: String, border: String) {
        switch theme {
        case .pure:
            return (bg: "#ffffff", text: "#222222", link: "#007aff", codeBg: "#f6f8fa", border: "#eaecef")
        case .solarizedLight:
            return (bg: "#fdf6e3", text: "#657b83", link: "#268bd2", codeBg: "#eee8d5", border: "#93a1a1")
        case .solarizedDark:
            return (bg: "#002b36", text: "#839496", link: "#268bd2", codeBg: "#073642", border: "#586e75")
        case .github:
            return (bg: "#ffffff", text: "#24292e", link: "#0366d6", codeBg: "#f6f8fa", border: "#e1e4e8")
        case .dracula:
            return (bg: "#282a36", text: "#f8f8f2", link: "#8be9fd", codeBg: "#44475a", border: "#6272a4")
        case .nord:
            return (bg: "#2e3440", text: "#d8dee9", link: "#88c0d0", codeBg: "#3b4252", border: "#4c566a")
        case .monokai:
            return (bg: "#272822", text: "#f8f8f2", link: "#66d9ef", codeBg: "#3e3d32", border: "#49483e")
        case .nightOwl:
            return (bg: "#011627", text: "#d6deeb", link: "#82aaff", codeBg: "#0b2942", border: "#5f7e97")
        }
    }

    private func resolveImageSource(_ source: String) -> String {
        if source.lowercased().hasPrefix("http") || source.hasPrefix("data:") {
            return source
        }

        var cleanPath = source
        if cleanPath.hasPrefix("file://") {
            cleanPath = String(cleanPath.dropFirst(7))
        }
        let decodedPath = cleanPath.removingPercentEncoding ?? cleanPath

        var possibleURLs: [URL] = [URL(fileURLWithPath: decodedPath)]
        if
            !decodedPath.hasPrefix("/"),
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first
        {
            possibleURLs.append(
                documentsURL.appendingPathComponent("Images").appendingPathComponent(decodedPath))
            possibleURLs.append(documentsURL.appendingPathComponent(decodedPath))
        }

        for url in possibleURLs {
            if FileManager.default.fileExists(atPath: url.path) {
                return url.absoluteString
            }
        }

        return source
    }

    private func mathematicalAndDiagramScripts(isDark: Bool) -> String {
        return """
        <!-- KaTeX Math Rendering -->
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body, {delimiters: [{left: '$$', right: '$$', display: true}, {left: '$', right: '$', display: false}, {left: '\\\\(', right: '\\\\)', display: false}, {left: '\\\\[', right: '\\\\]', display: true}], throwOnError: false});"></script>

        <!-- Mermaid Diagram Rendering -->
        <script type="module">
            import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
            mermaid.initialize({ startOnLoad: false, theme: '\(isDark ? "dark" : "default")' });
            document.addEventListener("DOMContentLoaded", async function() {
                const pres = document.querySelectorAll('pre code.language-mermaid, pre.mermaid, code.language-mermaid');
                pres.forEach(function(el) {
                    const pre = el.closest('pre') || el;
                    const div = document.createElement('div');
                    div.className = 'mermaid';
                    div.textContent = el.textContent;
                    pre.parentNode.replaceChild(div, pre);
                });
                try {
                    await mermaid.run();
                } catch(e) {
                    console.error("Mermaid error:", e);
                }
            });
        </script>
        """
    }

    private func wrapHTML(body: String, theme: MarkdownTheme) -> String {
        let css = themeCSS(for: theme)
        let scripts = mathematicalAndDiagramScripts(isDark: theme.isDark)

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
                \(body)
            </body>
            </html>
            """
    }

    private func themeCSS(for theme: MarkdownTheme) -> String {
        let colors: (bg: String, text: String, link: String, codeBg: String, border: String)

        switch theme {
        case .pure:
            colors = (
                bg: "#ffffff", text: "#222222", link: "#007aff", codeBg: "#f6f8fa",
                border: "#eaecef"
            )
        case .solarizedLight:
            colors = (
                bg: "#fdf6e3", text: "#657b83", link: "#268bd2", codeBg: "#eee8d5",
                border: "#93a1a1"
            )
        case .solarizedDark:
            colors = (
                bg: "#002b36", text: "#839496", link: "#268bd2", codeBg: "#073642",
                border: "#586e75"
            )
        case .github:
            colors = (
                bg: "#ffffff", text: "#24292e", link: "#0366d6", codeBg: "#f6f8fa",
                border: "#e1e4e8"
            )
        case .dracula:
            colors = (
                bg: "#282a36", text: "#f8f8f2", link: "#8be9fd", codeBg: "#44475a",
                border: "#6272a4"
            )
        case .nord:
            colors = (
                bg: "#2e3440", text: "#d8dee9", link: "#88c0d0", codeBg: "#3b4252",
                border: "#4c566a"
            )
        case .monokai:
            colors = (
                bg: "#272822", text: "#f8f8f2", link: "#66d9ef", codeBg: "#3e3d32",
                border: "#49483e"
            )
        case .nightOwl:
            colors = (
                bg: "#011627", text: "#d6deeb", link: "#82aaff", codeBg: "#0b2942",
                border: "#5f7e97"
            )
        }

        let isDark = theme.isDark

        // 读取 Markdown 特性开关；缺省值与 MarkdownSettingsView 中的 @AppStorage 默认值保持一致。
        let defaults = UserDefaults.standard
        let featureStrikethrough = defaults.object(forKey: "markdownFeatureStrikethrough") as? Bool ?? true
        let featureTaskList = defaults.object(forKey: "markdownFeatureTaskList") as? Bool ?? true
        let featureTable = defaults.object(forKey: "markdownFeatureTable") as? Bool ?? true
        let featureFootnote = defaults.object(forKey: "markdownFeatureFootnote") as? Bool ?? false

        var extras: [String] = []
        if !featureStrikethrough { extras.append("del, s { text-decoration: none; }") }
        if !featureTaskList { extras.append("input[type=\"checkbox\"] { display: none; }") }
        if !featureTable { extras.append("table, thead, tbody, tr, th, td { display: block; border: none; padding: 0; }") }
        if !featureFootnote { extras.append(".footnote-ref, .footnote-backref, .footnotes { display: none; }") }
        let extrasCSS = extras.joined(separator: "\n")

        return """
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    font-size: 11pt;
                    line-height: 1.6;
                    color: \(colors.text);
                    background-color: \(colors.bg);
                    max-width: 800px;
                    margin: 40px auto;
                    padding: 20px;
                    word-wrap: break-word;
                }
                a { color: \(colors.link); text-decoration: none; }
                a:hover { text-decoration: underline; }
                em { font-style: italic; color: \(colors.text); text-decoration: none !important; border-bottom: none !important; }
                strong { font-weight: bold; color: \(colors.text); text-decoration: none !important; }
                strong em, em strong { font-weight: bold; font-style: italic; color: \(colors.text); text-decoration: none !important; }
                u { text-decoration: underline; }
                del { text-decoration: line-through; opacity: 0.75; }

                h1, h2, h3, h4, h5, h6 { font-weight: 600; line-height: 1.25; margin-top: 24px; margin-bottom: 16px; color: \(colors.text); }
                h1 { font-size: 2em; border-bottom: 1px solid \(colors.border); padding-bottom: .3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid \(colors.border); padding-bottom: .3em; }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1em; }
                h5 { font-size: .875em; }
                h6 { font-size: .85em; color: \(colors.text); opacity: 0.75; }
                p { margin-top: 0; margin-bottom: 16px; white-space: pre-wrap; word-break: break-word; line-height: 1.7; }
                br { display: inline; }
                code {
                    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
                    background-color: \(colors.codeBg);
                    padding: .2em .4em;
                    border-radius: 3px;
                    font-size: 85%;
                }
                pre {
                    background-color: \(colors.codeBg);
                    padding: 16px;
                    border-radius: 6px;
                    overflow: auto;
                    line-height: 1.45;
                }
                pre code {
                    background-color: transparent;
                    padding: 0;
                    font-size: 100%;
                    word-break: normal;
                    white-space: pre;
                    color: inherit;
                }
                blockquote {
                    border-left: .25em solid \(colors.border);
                    padding: 0 1em;
                    color: \(colors.text);
                    opacity: 0.8;
                    margin: 0;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin-bottom: 16px;
                    display: block;
                    overflow: auto;
                }
                table th, table td {
                    border: 1px solid \(colors.border);
                    padding: 6px 13px;
                }
                table tr {
                    background-color: \(colors.bg);
                    border-top: 1px solid \(colors.border);
                }
                table tr:nth-child(2n) {
                    background-color: \(isDark ? colors.codeBg : "#f6f8fa");
                }
                img { max-width: 100%; box-sizing: content-box; background-color: #fff; }
                ul, ol { padding-left: 2em; margin-bottom: 16px; }
                ul.task-list { list-style-type: none; padding-left: 0; }
                ul.task-list li { list-style-type: none; }
                ul.task-list input[type="checkbox"] { margin-right: 6px; vertical-align: middle; }
                li + li { margin-top: .25em; }
                hr {
                    height: .25em;
                    padding: 0;
                    margin: 24px 0;
                    background-color: \(colors.border);
                    border: 0;
                }
                \(extrasCSS)
            </style>
            """
    }
}
