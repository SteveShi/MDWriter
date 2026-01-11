//
//  ExportService.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

class ExportService: NSObject {
    static let shared = ExportService()
    
    // 简单的 Markdown 转 HTML 解析器 (实际项目中建议使用 Ink 或 SwiftMark)
    // 这里为了不引入新依赖，我们用一个简化的替换逻辑，或者利用 MarkdownUI 的底层能力
    // 考虑到我们要导出漂亮的 PDF，最好的办法是构造一个包含 MarkdownUI 渲染结果的 View，然后渲染成图片或 PDF
    // 但那比较复杂。
    // 方案 B：使用 NSAttributedString 从 Markdown 解析，然后打印。
    
    func export(text: String, to url: URL, format: UTType) throws {
        // 允许纯文本或 Markdown 类型
        if format.conforms(to: .plainText) || format == .markdownDocument {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        
        switch format {
        case .pdf:
            // 使用 WebKit 生成 PDF
            createPDF(from: text, to: url)
            
        case .rtf, .rtfd:
             // 导出为富文本 (Word 可读)
            try createRTF(from: text, to: url)
            
        default:
            break
        }
    }
    
    // MARK: - PDF Generation via WebKit
    private func createPDF(from text: String, to url: URL) {
        let html = markdownToHTML(text)
        let webView = WKWebView()
        // 隐藏窗口，仅用于渲染
        webView.frame = CGRect(x: 0, y: 0, width: 800, height: 1100) 
        
        webView.loadHTMLString(html, baseURL: nil)
        
        // 监听加载完成 (简单起见，这里用稍微 hack 的延时，实际应使用 Delegate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let config = WKPDFConfiguration()
            
            webView.createPDF(configuration: config) { result in
                switch result {
                case .success(let data):
                    try? data.write(to: url)
                    print("PDF saved to: \(url.path)")
                case .failure(let error):
                    print("PDF Generation Error: \(error)")
                }
            }
        }
    }
    
    // MARK: - RTF Generation
    private func createRTF(from text: String, to url: URL) throws {
        // 将 Markdown 转换为带属性的字符串
        // 这里简单地用 HTML 作为中间格式，因为 NSAttributedString 可以很好地解析 HTML
        let html = markdownToHTML(text)
        guard let data = html.data(using: .utf8) else { return }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            let rtfData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            try rtfData.write(to: url)
        }
    }
    
    // 简单的 Markdown -> HTML 转换 (带 CSS)
    private func markdownToHTML(_ markdown: String) -> String {
        // ⚠️ 注意：这是一个极简的转换，不支持复杂语法。
        // 实际生产环境应该引入 'Ink' 或 'Down' 库。
        // 为了演示，我们将换行转换为 <br>，标题转换为 <h1> 等
        
        var htmlBody = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        
        // 简单处理标题 (仅限演示)
        // 实际请务必集成真正的 Parser
        
        let css = """
        <style>
            body { font-family: "New York", "Georgia", serif; font-size: 14pt; line-height: 1.6; color: #333; max-width: 700px; margin: 40px auto; padding: 20px; }
            h1 { font-size: 24pt; border-bottom: 1px solid #eee; padding-bottom: 10px; }
            h2 { font-size: 20pt; margin-top: 30px; }
            h3 { font-size: 16pt; }
            code { font-family: "Menlo", monospace; background: #f5f5f5; padding: 2px 5px; border-radius: 3px; }
            pre { background: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
            img { max-width: 100%; height: auto; }
            blockquote { border-left: 4px solid #ddd; padding-left: 15px; color: #666; }
        </style>
        """
        
        // 为了让演示有效，我们将 Markdown 原文包裹在 <pre> 中，或者您可以手动集成 Down 库
        // 更好的方案：使用 swift-markdown-ui 已经引入的 cmark 库！
        // 但 cmark 的 swift 绑定在 markdown-ui 内部是私有的吗？
        // 我们尝试直接用最简单的换行处理，配合 CSS white-space: pre-wrap
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            \(css)
        </head>
        <body>
            <div style="white-space: pre-wrap;">\(htmlBody)</div>
        </body>
        </html>
        """
    }
}

// 扩展 UTType 以支持 Word
extension UTType {
    static var wordDocument: UTType {
        UTType(importedAs: "com.microsoft.word.doc")
    }
}
