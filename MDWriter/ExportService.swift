//
//  ExportService.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers
import Ink

class ExportService: NSObject {
    static let shared = ExportService()
    
    // 使用 Ink 库进行 Markdown 解析
    
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
    
    // 使用 Ink 将 Markdown 转换为 HTML (带 CSS)
    private func markdownToHTML(_ markdown: String) -> String {
        let parser = MarkdownParser()
        let result = parser.parse(markdown)
        let htmlBody = result.html
        
        let css = """
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; 
                font-size: 12pt; 
                line-height: 1.6; 
                color: #24292e; 
                max-width: 800px; 
                margin: 40px auto; 
                padding: 20px; 
            }
            h1 { font-size: 2em; border-bottom: 1px solid #eaecef; padding-bottom: .3em; margin-top: 24px; margin-bottom: 16px; font-weight: 600; }
            h2 { font-size: 1.5em; border-bottom: 1px solid #eaecef; padding-bottom: .3em; margin-top: 24px; margin-bottom: 16px; font-weight: 600; }
            h3 { font-size: 1.25em; margin-top: 24px; margin-bottom: 16px; font-weight: 600; }
            code { 
                font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; 
                background-color: rgba(27,31,35,.05); 
                padding: .2em .4em; 
                border-radius: 3px; 
                font-size: 85%;
            }
            pre { 
                background-color: #f6f8fa; 
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
            }
            img { max-width: 100%; box-sizing: content-box; background-color: #fff; }
            blockquote { 
                border-left: .25em solid #dfe2e5; 
                padding: 0 1em; 
                color: #6a737d; 
                margin: 0 0 16px 0;
            }
            table { border-collapse: collapse; width: 100%; margin-bottom: 16px; }
            table th, table td { border: 1px solid #dfe2e5; padding: 6px 13px; }
            table tr { background-color: #fff; border-top: 1px solid #c6cbd1; }
            table tr:nth-child(2n) { background-color: #f6f8fa; }
            ul, ol { padding-left: 2em; }
            li + li { margin-top: .25em; }
        </style>
        """
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            \(css)
        </head>
        <body>
            \(htmlBody)
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
