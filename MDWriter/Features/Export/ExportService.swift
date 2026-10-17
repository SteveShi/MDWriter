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

        let storedThemeID = UserDefaults.standard.string(forKey: "markdownTheme")
        let theme = storedThemeID.flatMap(MarkdownTheme.init(rawValue:)) ?? .pure

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

    func renderCardHTML(from markdown: String, title: String, theme: MarkdownTheme = .pure) -> String {
        return renderer.renderCardHTML(from: markdown, title: title, theme: theme)
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

    func createPDFAsync(from text: String, theme: MarkdownTheme = .pure) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            createPDF(from: text, theme: theme) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Image Generation (Social Card)
    func createImage(
        from text: String,
        title: String,
        theme: MarkdownTheme = .pure,
        completion: @escaping (Result<NSImage, Error>) -> Void
    ) {
        let html = renderCardHTML(from: text, title: title, theme: theme)
        let generator = ImageGenerator()
        generator.generate(html: html, completion: completion)
    }

    func createImageAsync(
        from text: String,
        title: String,
        theme: MarkdownTheme = .pure
    ) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            createImage(from: text, title: title, theme: theme) { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
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

    // MARK: - Combined Book Mode Assembly
    /// Assembles multiple notes into a structured multi-chapter Book Markdown document.
    func assembleBookMarkdown(notes: [Note], bookTitle: String) -> String {
        let sortedNotes = notes.sorted { (n1, n2) -> Bool in
            if n1.order != n2.order { return n1.order < n2.order }
            return n1.createdAt < n2.createdAt
        }

        let mainTitle = bookTitle.isEmpty ? String(localized: "Compiled Book") : bookTitle
        var sb = "# \(mainTitle)\n\n"
        sb += "> \(String(localized: "Generated with MDWriter Book Mode")) · \(sortedNotes.count) \(String(localized: "chapters"))\n\n"
        sb += "## \(String(localized: "Table of Contents"))\n\n"

        for (idx, note) in sortedNotes.enumerated() {
            let title = note.title.isEmpty ? "\(String(localized: "Chapter")) \(idx + 1)" : note.title
            sb += "\(idx + 1). [\(title)](#chapter-\(idx + 1))\n"
        }
        sb += "\n---\n\n"

        for (idx, note) in sortedNotes.enumerated() {
            let title = note.title.isEmpty ? "\(String(localized: "Chapter")) \(idx + 1)" : note.title
            sb += "<a name=\"chapter-\(idx + 1)\"></a>\n\n"
            sb += "## \(idx + 1). \(title)\n\n"
            sb += note.content.trimmingCharacters(in: .whitespacesAndNewlines)
            sb += "\n\n---\n\n"
        }

        return sb
    }

    // MARK: - Universal Document Export Helper
    func exportDocument(
        text: String,
        title: String,
        formatString: String,
        destinationPath: String? = nil
    ) async throws -> String {
        let fmt = formatString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let storedThemeID = UserDefaults.standard.string(forKey: "markdownTheme")
        let theme = storedThemeID.flatMap(MarkdownTheme.init(rawValue:)) ?? .pure

        let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled"
            : title.replacingOccurrences(of: "/", with: "-")
                   .replacingOccurrences(of: ":", with: "-")

        let ext: String
        switch fmt {
        case "pdf": ext = "pdf"
        case "html": ext = "html"
        case "rtf": ext = "rtf"
        case "image", "png", "card": ext = "png"
        default: ext = "md"
        }

        let targetURL: URL
        if let dest = destinationPath?.trimmingCharacters(in: .whitespacesAndNewlines), !dest.isEmpty {
            let expanded = (dest as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                targetURL = URL(fileURLWithPath: expanded).appendingPathComponent("\(sanitizedTitle).\(ext)")
            } else {
                targetURL = URL(fileURLWithPath: expanded)
            }
        } else {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            targetURL = downloads.appendingPathComponent("\(sanitizedTitle).\(ext)")
        }

        switch fmt {
        case "pdf":
            let pdfData = try await createPDFAsync(from: text, theme: theme)
            try pdfData.write(to: targetURL)
        case "html":
            let html = renderHTML(from: text, theme: theme)
            guard let htmlData = html.data(using: .utf8) else {
                throw NSError(domain: "ExportService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to encode HTML"])
            }
            try htmlData.write(to: targetURL)
        case "rtf":
            let html = renderHTML(from: text, theme: theme)
            guard let data = html.data(using: .utf8) else {
                throw NSError(domain: "ExportService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to encode HTML"])
            }
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            let attributed = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            let rtfData = try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try rtfData.write(to: targetURL)
        case "image", "png", "card":
            let image = try await createImageAsync(from: text, title: title, theme: theme)
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "ExportService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])
            }
            try pngData.write(to: targetURL)
        default: // markdown
            try text.write(to: targetURL, atomically: true, encoding: .utf8)
        }

        return "Successfully exported document '\(title)' as \(ext.uppercased()) to: \(targetURL.path)"
    }
}

// MARK: - Private helper to manage PDF generation lifecycle
private class PDFGenerator: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var selfRetain: PDFGenerator?

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
            webView.loadHTMLString(html, baseURL: nil)
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
        webView = nil
        completion = nil
        selfRetain = nil
    }
}

// MARK: - Private helper to manage Social Card / Image generation lifecycle
private class ImageGenerator: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((Result<NSImage, Error>) -> Void)?
    private var selfRetain: ImageGenerator?

    func generate(html: String, completion: @escaping (Result<NSImage, Error>) -> Void) {
        self.completion = completion
        self.selfRetain = self

        DispatchQueue.main.async {
            let config = WKWebViewConfiguration()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 720, height: 1000), configuration: config)
            webView.navigationDelegate = self
            self.webView = webView
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let wv = self.webView else { return }
            wv.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                guard let self = self, let wv = self.webView else { return }
                let height = (result as? CGFloat) ?? 1000
                wv.frame = CGRect(x: 0, y: 0, width: 720, height: max(height + 20, 300))

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let snapshotConfig = WKSnapshotConfiguration()
                    wv.takeSnapshot(with: snapshotConfig) { image, error in
                        if let image = image {
                            self.completion?(.success(image))
                        } else if let error = error {
                            self.completion?(.failure(error))
                        } else {
                            self.completion?(.failure(NSError(domain: "ExportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to snapshot card image"])))
                        }
                        self.cleanup()
                    }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion?(.failure(error))
        cleanup()
    }

    private func cleanup() {
        webView = nil
        completion = nil
        selfRetain = nil
    }
}
