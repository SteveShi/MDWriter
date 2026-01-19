//
//  WebView.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/13.
//

import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct WebView: PlatformViewRepresentable {
    let html: String

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground") // 替代 drawsBackground = false
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
    #endif
}