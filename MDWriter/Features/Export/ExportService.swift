import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor
class ExportService: NSObject {
    static let shared = ExportService()
    private let renderer = MDWMarkdownRenderer()

    func export(text: String, to url: URL, format: UTType) throws {
        if format.conforms(to: .plainText) || format == .markdownDocument {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }

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
