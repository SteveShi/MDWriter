//
//  WebView.swift
//  MDWriter
//

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 将 HTML 写入 Documents 下的临时文件，以便 WebKit 同时访问该文件和同级/上级的图片资源
        guard let tempURL = getTemporaryHTMLURL() else {
            nsView.loadHTMLString(html, baseURL: nil)
            return
        }

        do {
            try html.write(to: tempURL, atomically: true, encoding: .utf8)

            if let documentsURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first {
                // 授权访问 Documents 目录（图片所在的 Images 文件夹就在其中）
                nsView.loadFileURL(tempURL, allowingReadAccessTo: documentsURL)
            } else {
                nsView.loadHTMLString(html, baseURL: nil)
            }
        } catch {
            print("WebView: Failed to save temp html: \(error)")
            nsView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func getTemporaryHTMLURL() -> URL? {
        guard
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        else { return nil }
        // 创建一个位于 Documents 下的临时目录，确保 WebKit 有权限同时读取 HTML 和图片
        let tempDir = documentsURL.appendingPathComponent(".mdwriter_temp")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.appendingPathComponent("preview_\(UUID().uuidString).html")
    }
}
