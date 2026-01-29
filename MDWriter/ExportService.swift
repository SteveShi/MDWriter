import AppKit
import Markdown
import SwiftUI
import UniformTypeIdentifiers
import WebKit

class ExportService: NSObject {
    static let shared = ExportService()
    private let renderer = MarkdownRenderer()

    func export(text: String, to url: URL, format: UTType) throws {
        if format.conforms(to: .plainText) || format == .markdownDocument {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }

        // For export, we default to the currently selected theme, or a specific "Print" friendly theme if preferred.
        // For now, let's use the user's selected theme but maybe force a light background for PDF if strictly needed.
        // But user asked for Themes support, so we respect the selection.
        let themeName = UserDefaults.standard.string(forKey: "markdownTheme") ?? "Pure"
        let theme = MarkdownTheme(rawValue: themeName) ?? .pure

        switch format {
        case .pdf:
            createPDF(from: text, theme: theme) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: url)
                        } catch {
                            print("PDF Write Error: \(error)")
                        }
                    case .failure(let error):
                        print("PDF Creation Error: \(error)")
                    }
                }
            }
        case .rtf, .rtfd:
            try createRTF(from: text, to: url, theme: theme)
        default:
            break
        }
    }

    func renderHTML(from markdown: String, theme: MarkdownTheme = .pure) -> String {
        return renderer.renderHTML(from: markdown, theme: theme)
    }

    // MARK: - PDF Generation
    func createPDF(
        from text: String, theme: MarkdownTheme = .pure,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let html = renderHTML(from: text, theme: theme)
        let generator = PDFGenerator()
        generator.generate(html: html, completion: completion)
    }

    // MARK: - RTF Generation
    private func createRTF(from text: String, to url: URL, theme: MarkdownTheme) throws {
        let html = renderHTML(from: text, theme: theme)
        guard let data = html.data(using: .utf8) else { return }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]

        DispatchQueue.main.async {
            do {
                if let attributedString = try? NSAttributedString(
                    data: data, options: options, documentAttributes: nil)
                {
                    let rtfData = try attributedString.data(
                        from: NSRange(location: 0, length: attributedString.length),
                        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                    try rtfData.write(to: url)
                }
            } catch {
                print("RTF Generation Error: \(error)")
            }
        }
    }
}

// Private helper to manage PDF generation lifecycle
private class PDFGenerator: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var selfRetain: PDFGenerator?
    private var tempURL: URL?

    func generate(html: String, completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
        self.selfRetain = self

        DispatchQueue.main.async {
            let config = WKWebViewConfiguration()
            // A4 Size: 595 x 842 points
            let webView = WKWebView(
                frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: config)
            webView.navigationDelegate = self
            self.webView = webView

            // 使用 Documents 下的临时目录，确保 WebKit 权限一致
            guard
                let documentsURL = FileManager.default.urls(
                    for: .documentDirectory, in: .userDomainMask
                ).first
            else {
                webView.loadHTMLString(html, baseURL: nil)
                return
            }

            let tempDir = documentsURL.appendingPathComponent(".mdwriter_temp")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let tempURL = tempDir.appendingPathComponent("export_\(UUID().uuidString).html")
            self.tempURL = tempURL

            do {
                try html.write(to: tempURL, atomically: true, encoding: .utf8)
                // 授权 Documents 目录读取权限
                webView.loadFileURL(tempURL, allowingReadAccessTo: documentsURL)
            } catch {
                print("Failed to save temp html: \(error)")
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKPDFConfiguration()

        // Wait a bit for rendering to finish (images, etc)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.webView?.createPDF(configuration: config) { [weak self] result in
                self?.completion?(result)
                self?.cleanup()
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion?(.failure(error))
        cleanup()
    }

    private func cleanup() {
        if let tempURL = tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        webView = nil
        completion = nil
        selfRetain = nil
    }
}

// MARK: - Markdown Renderer (Included here to avoid project file issues)

struct MarkdownRenderer {
    func renderHTML(from markdown: String, theme: MarkdownTheme) -> String {
        let document = Document(parsing: markdown)
        var visitor = HTMLVisitor()
        let body = visitor.visit(document)
        return wrapHTML(body: body, theme: theme)
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

        // Helper to determine if we need dark scrollbars/ui hints
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

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    mutating func defaultVisit(_ markup: Markup) -> String {
        return markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        return document.children.map { visit($0) }.joined()
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let tag = "h\(heading.level)"
        return "<\(tag)>\(heading.children.map { visit($0) }.joined())</\(tag)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        return "<p>\(paragraph.children.map { visit($0) }.joined())</p>"
    }

    mutating func visitText(_ text: Markdown.Text) -> String {
        return text.string.htmlEscaped()
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        return "<em>\(emphasis.children.map { visit($0) }.joined())</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        return "<strong>\(strong.children.map { visit($0) }.joined())</strong>"
    }

    mutating func visitLink(_ link: Markdown.Link) -> String {
        let dest = link.destination ?? ""
        return "<a href=\"\(dest)\">\(link.children.map { visit($0) }.joined())</a>"
    }

    mutating func visitImage(_ image: Markdown.Image) -> String {
        let source = image.source ?? ""
        let title = image.title ?? ""
        let alt = image.plainText

        // 如果是网络图片或 Base64，直接返回
        if source.lowercased().hasPrefix("http") || source.hasPrefix("data:") {
            return "<img src=\"\(source)\" title=\"\(title)\" alt=\"\(alt)\" />"
        }

        // 处理本地文件路径
        var cleanPath = source
        if cleanPath.hasPrefix("file://") {
            cleanPath = String(cleanPath.dropFirst(7))
        }
        let decodedPath = cleanPath.removingPercentEncoding ?? cleanPath

        // 获取 Documents 目录
        guard
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        else {
            return "<img src=\"\(source)\" title=\"\(title)\" alt=\"\(alt)\" />"
        }

        // 智能尝试解析路径
        let possibleURLs: [URL] = [
            documentsURL.appendingPathComponent("Images").appendingPathComponent(decodedPath),  // Documents/Images/file
            documentsURL.appendingPathComponent(decodedPath),  // Documents/file
            URL(fileURLWithPath: decodedPath),  // Absolute path
        ]

        for url in possibleURLs {
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: url.path) {
                // 找到文件，使用绝对文件路径
                // 注意：必须对路径进行百分号编码，否则 WebKit 可能无法加载带空格的路径
                let absoluteString = url.absoluteString
                return "<img src=\"\(absoluteString)\" title=\"\(title)\" alt=\"\(alt)\" />"
            }
        }

        // 如果没找到文件，尝试构建一个合理的 Fallback (假设它在 Documents/Images 下)
        // 这样如果文件后续被放入，或许能加载（但在 WebKit 中通常需要绝对路径）
        let fallbackURL = documentsURL.appendingPathComponent("Images").appendingPathComponent(
            decodedPath)
        return "<img src=\"\(fallbackURL.absoluteString)\" title=\"\(title)\" alt=\"\(alt)\" />"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let langClass = codeBlock.language.map { " class=\"language-\($0)\"" } ?? ""
        return "<pre><code\(langClass)>\(codeBlock.code.htmlEscaped())</code></pre>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        return "<code>\(inlineCode.code.htmlEscaped())</code>"
    }

    mutating func visitUnorderedList(_ list: Markdown.UnorderedList) -> String {
        return "<ul>\(list.children.map { visit($0) }.joined())</ul>"
    }

    mutating func visitOrderedList(_ list: Markdown.OrderedList) -> String {
        return "<ol>\(list.children.map { visit($0) }.joined())</ol>"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        return "<li>\(listItem.children.map { visit($0) }.joined())</li>"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        return "<blockquote>\(blockQuote.children.map { visit($0) }.joined())</blockquote>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        return "<hr />"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        return " "
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        return "<br />"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        return inlineHTML.rawHTML
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> String {
        return htmlBlock.rawHTML
    }

    mutating func visitTable(_ table: Markdown.Table) -> String {
        return "<table>\(table.children.map { visit($0) }.joined())</table>"
    }

    mutating func visitTableHead(_ tableHead: Markdown.Table.Head) -> String {
        return "<thead>\(tableHead.children.map { visit($0) }.joined())</thead>"
    }

    mutating func visitTableBody(_ tableBody: Markdown.Table.Body) -> String {
        return "<tbody>\(tableBody.children.map { visit($0) }.joined())</tbody>"
    }

    mutating func visitTableRow(_ tableRow: Markdown.Table.Row) -> String {
        return "<tr>\(tableRow.children.map { visit($0) }.joined())</tr>"
    }

    mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) -> String {
        let tag = tableCell.parent is Markdown.Table.Head ? "th" : "td"
        return "<\(tag)>\(tableCell.children.map { visit($0) }.joined())</\(tag)>"
    }
}

extension String {
    func htmlEscaped() -> String {
        return self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// 扩展 UTType 以支持 Word
extension UTType {
    static var wordDocument: UTType {
        UTType(importedAs: "com.microsoft.word.doc")
    }
}
