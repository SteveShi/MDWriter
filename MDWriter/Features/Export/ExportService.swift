import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor
class ExportService: NSObject {
    static let shared = ExportService()
    private let renderer = MDWMarkdownRenderer()

    private var savedTheme: MarkdownTheme {
        MarkdownTheme.fromStorage(UserDefaults.standard.string(forKey: "markdownTheme"))
    }

    private var savedExportStyle: ExportStyle {
        let raw = UserDefaults.standard.string(forKey: "exportStyle")
        return raw.flatMap(ExportStyle.init(rawValue:)) ?? .swiss
    }

    private var savedPaperSize: ExportPaperSize {
        let raw = UserDefaults.standard.string(forKey: "exportPaperSize")
        return raw.flatMap(ExportPaperSize.init(rawValue:)) ?? .a4
    }

    func export(
        text: String,
        to url: URL,
        format: UTType,
        style: ExportStyle? = nil,
        paperSize: ExportPaperSize? = nil
    ) throws {
        if format.conforms(to: .plainText) || format == .markdownDocument {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }

        let theme = savedTheme
        let resolvedStyle = style ?? savedExportStyle
        let resolvedPaper = paperSize ?? savedPaperSize

        switch format {
        case .pdf:
            createPDF(from: text, style: resolvedStyle, theme: theme, paperSize: resolvedPaper) { result in
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
        case .html:
            let html = renderHTML(from: text, style: resolvedStyle, theme: theme, paperSize: resolvedPaper)
            try html.write(to: url, atomically: true, encoding: .utf8)
        case .rtf, .rtfd:
            try createRTF(from: text, to: url, style: resolvedStyle, theme: theme)
        default:
            break
        }
    }

    func renderHTML(
        from markdown: String,
        style: ExportStyle? = nil,
        theme: MarkdownTheme? = nil,
        paperSize: ExportPaperSize? = nil
    ) -> String {
        renderer.renderHTML(
            from: markdown,
            style: style ?? savedExportStyle,
            theme: theme ?? savedTheme,
            paperSize: paperSize ?? savedPaperSize
        )
    }

    func renderCardHTML(
        from markdown: String,
        title: String,
        style: ExportStyle? = nil,
        theme: MarkdownTheme? = nil
    ) -> String {
        renderer.renderCardHTML(
            from: markdown,
            title: title,
            style: style ?? savedExportStyle,
            theme: theme ?? savedTheme
        )
    }

    // MARK: - Paginated Vector PDF Generation (NSPrintOperation on WKWebView)

    func createPDF(
        from text: String,
        style: ExportStyle? = nil,
        theme: MarkdownTheme? = nil,
        paperSize: ExportPaperSize? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let resolvedStyle = style ?? savedExportStyle
        let resolvedTheme = theme ?? savedTheme
        let resolvedPaper = paperSize ?? savedPaperSize
        let html = renderer.renderHTML(
            from: text,
            style: resolvedStyle,
            theme: resolvedTheme,
            paperSize: resolvedPaper
        )
        let generator = PaginatedPDFGenerator()
        generator.generate(html: html, paperSize: resolvedPaper, completion: completion)
    }

    func createPDFAsync(
        from text: String,
        style: ExportStyle? = nil,
        theme: MarkdownTheme? = nil,
        paperSize: ExportPaperSize? = nil
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            createPDF(from: text, style: style, theme: theme, paperSize: paperSize) { result in
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
        style: ExportStyle? = nil,
        theme: MarkdownTheme? = nil,
        completion: @escaping (Result<NSImage, Error>) -> Void
    ) {
        let html = renderCardHTML(from: text, title: title, style: style, theme: theme)
        let generator = ImageGenerator()
        generator.generate(html: html, completion: completion)
    }

    func createImageAsync(
        from text: String,
        title: String,
        style: ExportStyle? = nil,
        theme: MarkdownTheme? = nil
    ) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            createImage(from: text, title: title, style: style, theme: theme) { result in
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

    private func createRTF(from text: String, to url: URL, style: ExportStyle, theme: MarkdownTheme) throws {
        let html = renderer.renderHTML(
            from: text,
            style: style,
            theme: theme,
            paperSize: savedPaperSize,
            includeScripts: false
        )
        guard let data = html.data(using: .utf8) else {
            throw NSError(
                domain: "ExportService", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode HTML for RTF export"]
            )
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
        let rtfData = try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        try rtfData.write(to: url, options: .atomic)
    }

    // MARK: - Combined Book Mode Assembly

    func assembleBookMarkdown(notes: [Note], bookTitle: String) -> String {
        let sortedNotes = notes.sorted { n1, n2 in
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
        let theme = savedTheme
        let style = savedExportStyle
        let paper = savedPaperSize

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
            let pdfData = try await createPDFAsync(from: text, style: style, theme: theme, paperSize: paper)
            try pdfData.write(to: targetURL, options: .atomic)
        case "html":
            let html = renderHTML(from: text, style: style, theme: theme, paperSize: paper)
            try html.write(to: targetURL, atomically: true, encoding: .utf8)
        case "rtf":
            try createRTF(from: text, to: targetURL, style: style, theme: theme)
        case "image", "png", "card":
            let image = try await createImageAsync(from: text, title: title, style: style, theme: theme)
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [:])
            else {
                throw NSError(
                    domain: "ExportService", code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"]
                )
            }
            try pngData.write(to: targetURL, options: .atomic)
        default:
            try text.write(to: targetURL, atomically: true, encoding: .utf8)
        }

        return "Successfully exported document '\(title)' as \(ext.uppercased()) to: \(targetURL.path)"
    }
}

// MARK: - True Paginated Vector PDF Generator (NSPrintOperation + @page CSS)

@MainActor
private final class PaginatedPDFGenerator: NSObject, WKNavigationDelegate {
    private var offscreenWindow: NSWindow?
    private var webView: WKWebView?
    private var paperSize: ExportPaperSize = .a4
    private var outputURL: URL?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var selfRetain: PaginatedPDFGenerator?

    func generate(
        html: String,
        paperSize: ExportPaperSize,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        self.paperSize = paperSize
        self.completion = completion
        self.selfRetain = self

        let pagePt = paperSize.sizeInPoints
        let rect = NSRect(origin: .zero, size: pagePt)

        // WKWebView.printOperation 需要宿主窗口上下文以正确触发布局与分页管线
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.orderOut(nil)

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: rect, configuration: config)
        webView.navigationDelegate = self
        window.contentView = webView

        self.offscreenWindow = window
        self.webView = webView
        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 等待所有字体和内嵌图片解码完毕，再触发分页打印
        let readyJS = """
            (async () => {
                if (document.fonts && document.fonts.ready) {
                    await document.fonts.ready;
                }
                const imgs = Array.from(document.images || []);
                await Promise.all(imgs.map(img => img.complete ? Promise.resolve() : new Promise(r => { img.onload = r; img.onerror = r; })));
                return true;
            })();
            """
        webView.evaluateJavaScript(readyJS) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self?.runPaginatedPrint()
            }
        }
    }

    private func runPaginatedPrint() {
        guard let webView = webView, let window = offscreenWindow else {
            finish(with: .failure(NSError(domain: "ExportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebView unavailable"])))
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MDWriter-Export-\(UUID().uuidString).pdf")
        self.outputURL = tempURL

        let printInfo = NSPrintInfo()
        printInfo.paperSize = paperSize.sizeInPoints
        // 页边距交由 CSS @page 精确控制，避免双层边距叠加导致裁切
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = tempURL

        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false
        printOp.runModal(
            for: window,
            delegate: self,
            didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func printOperationDidRun(
        _ printOperation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        defer {
            if let url = outputURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        guard success, let url = outputURL, let data = try? Data(contentsOf: url), !data.isEmpty else {
            // 若打印通道异常，兜底尝试 WKWebView.createPDF
            fallbackCreatePDF()
            return
        }
        finish(with: .success(data))
    }

    private func fallbackCreatePDF() {
        guard let webView = webView else {
            finish(with: .failure(NSError(domain: "ExportService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])))
            return
        }
        let pdfConfig = WKPDFConfiguration()
        webView.createPDF(configuration: pdfConfig) { [weak self] result in
            self?.finish(with: result)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(with: .failure(error))
    }

    private func finish(with result: Result<Data, Error>) {
        completion?(result)
        webView?.navigationDelegate = nil
        webView = nil
        offscreenWindow?.close()
        offscreenWindow = nil
        outputURL = nil
        completion = nil
        selfRetain = nil
    }
}

// MARK: - Social Card / Image Generator

@MainActor
private final class ImageGenerator: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((Result<NSImage, Error>) -> Void)?
    private var selfRetain: ImageGenerator?

    func generate(html: String, completion: @escaping (Result<NSImage, Error>) -> Void) {
        self.completion = completion
        self.selfRetain = self

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 720, height: 1000), configuration: config)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let readyJS = """
            (async () => {
                if (document.fonts && document.fonts.ready) { await document.fonts.ready; }
                const imgs = Array.from(document.images || []);
                await Promise.all(imgs.map(img => img.complete ? Promise.resolve() : new Promise(r => { img.onload = r; img.onerror = r; })));
                return document.body.scrollHeight;
            })();
            """
        webView.evaluateJavaScript(readyJS) { [weak self] result, _ in
            guard let self = self, let wv = self.webView else { return }
            let height: CGFloat = (result as? NSNumber).map { CGFloat($0.doubleValue) } ?? 1000
            wv.frame = CGRect(x: 0, y: 0, width: 720, height: max(height + 20, 320))

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let snapshotConfig = WKSnapshotConfiguration()
                wv.takeSnapshot(with: snapshotConfig) { image, error in
                    if let image = image {
                        self.completion?(.success(image))
                    } else if let error = error {
                        self.completion?(.failure(error))
                    } else {
                        self.completion?(.failure(
                            NSError(
                                domain: "ExportService", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to snapshot card image"]
                            )
                        ))
                    }
                    self.cleanup()
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion?(.failure(error))
        cleanup()
    }

    private func cleanup() {
        webView?.navigationDelegate = nil
        webView = nil
        completion = nil
        selfRetain = nil
    }
}
