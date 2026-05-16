//
//  MarkdownRenderService.swift
//  MDWriter
//
//  Markdown → HTML renderer used by Export (PDF/RTF) and preview surfaces.
//

import Foundation
import MDEditor

struct MDWMarkdownRenderer {
    func renderHTML(from markdown: String, theme: MarkdownTheme) -> String {
        let body = MarkdownConverter.toHTML(markdown, imageResolver: resolveImageSource)
        return wrapHTML(body: body, theme: theme)
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

    private func wrapHTML(body: String, theme: MarkdownTheme) -> String {
        let css = themeCSS(for: theme)

        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                \(css)
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

        let isDark = [MarkdownTheme.dracula, .nord, .monokai, .nightOwl, .solarizedDark].contains(
            theme)

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

                h1, h2, h3, h4, h5, h6 { font-weight: 600; line-height: 1.25; margin-top: 24px; margin-bottom: 16px; color: \(colors.text); }
                h1 { font-size: 2em; border-bottom: 1px solid \(colors.border); padding-bottom: .3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid \(colors.border); padding-bottom: .3em; }
                p { margin-top: 0; margin-bottom: 16px; }
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
                li + li { margin-top: .25em; }
                hr {
                    height: .25em;
                    padding: 0;
                    margin: 24px 0;
                    background-color: \(colors.border);
                    border: 0;
                }
            </style>
            """
    }
}
