//
//  ExportPreviewView.swift
//  MDWriter
//
//  真正的所见即所得导出预览（借鉴 Ulysses 导出样式选择器）：
//  - PDF / HTML 预览直接渲染与最终导出同源的 HTML + 出版样式 CSS
//  - 支持独立切换 6 套出版导出风格与 A4 / US Letter 纸张规格
//

import AppKit
import Foundation
import MDEditorKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

enum ExportPreviewMode: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case html = "HTML"
    case image = "Social Card"

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .pdf: return LocalizedStringKey("PDF Document")
        case .html: return LocalizedStringKey("HTML")
        case .image: return LocalizedStringKey("Social Card (Image)")
        }
    }
}

struct ExportPreviewView: View {
    let text: String
    let fileName: String
    @Environment(\.dismiss) var dismiss

    @AppStorage("exportStyle") private var selectedStyleRaw: String = ExportStyle.swiss.rawValue
    @AppStorage("exportPaperSize") private var selectedPaperRaw: String = ExportPaperSize.a4.rawValue
    @AppStorage("markdownTheme") private var markdownThemeRaw: String = MarkdownTheme.pure.rawValue

    @State private var mode: ExportPreviewMode = .pdf
    @State private var isExporting = false
    @State private var showPDFExporter = false
    @State private var showHTMLExporter = false
    @State private var showImageExporter = false
    @State private var pdfData: Data?
    @State private var htmlData: Data?
    @State private var pngData: Data?
    @State private var cardPreviewImage: NSImage?
    @State private var renderedHTML: String = ""
    @State private var hasCopied = false

    private var selectedStyle: ExportStyle {
        ExportStyle(rawValue: selectedStyleRaw) ?? .swiss
    }

    private var selectedPaper: ExportPaperSize {
        ExportPaperSize(rawValue: selectedPaperRaw) ?? .a4
    }

    private var activeEditorTheme: MarkdownTheme {
        MarkdownTheme(rawValue: markdownThemeRaw) ?? .pure
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部控制栏：格式切换 + 出版风格选择 + 纸张尺寸
                HStack(spacing: 14) {
                    Picker("", selection: $mode) {
                        ForEach(ExportPreviewMode.allCases) { m in
                            Text(m.localizedName).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)

                    Spacer()

                    // 出版导出风格选择器（Ulysses 风格解耦设计）
                    Picker(LocalizedStringKey("Export Style"), selection: $selectedStyleRaw) {
                        ForEach(ExportStyle.allCases) { style in
                            Label(style.displayName, systemImage: style.iconName)
                                .tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 155)

                    if mode == .pdf {
                        Picker(LocalizedStringKey("Paper Size"), selection: $selectedPaperRaw) {
                            ForEach(ExportPaperSize.allCases) { paper in
                                Text(paper.displayName).tag(paper.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 105)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

                Divider()

                // 预览画布（PDF/HTML 使用与最终导出完全同源的 WebKit 渲染）
                Group {
                    if mode == .pdf || mode == .html {
                        ZStack {
                            Color(NSColor.underPageBackgroundColor)

                            ExportWebPreview(html: renderedHTML)
                                .frame(
                                    maxWidth: mode == .pdf
                                        ? (selectedPaper.sizeInPoints.width + 64)
                                        : .infinity
                                )
                                .background(Color.white)
                                .cornerRadius(mode == .pdf ? 8 : 0)
                                .shadow(
                                    color: .black.opacity(mode == .pdf ? 0.12 : 0),
                                    radius: mode == .pdf ? 10 : 0,
                                    x: 0, y: 4
                                )
                                .padding(mode == .pdf ? 20 : 0)
                        }
                    } else {
                        ScrollView {
                            VStack {
                                if let img = cardPreviewImage {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                                        .padding(24)
                                } else {
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .controlSize(.regular)
                                        Text(LocalizedStringKey("Rendering Social Card..."))
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(minHeight: 300)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .background(Color(NSColor.underPageBackgroundColor))
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    switch mode {
                    case .image:
                        Button {
                            copyImageToClipboard()
                        } label: {
                            Label(
                                hasCopied ? LocalizedStringKey("Copied!") : LocalizedStringKey("Copy Image"),
                                systemImage: hasCopied ? "checkmark" : "doc.on.doc"
                            )
                        }
                        .disabled(isExporting)

                        Button {
                            prepareImageExport()
                        } label: {
                            if isExporting {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(LocalizedStringKey("Save as Image..."))
                            }
                        }
                        .disabled(isExporting)

                    case .html:
                        Button {
                            prepareHTMLExport()
                        } label: {
                            Text(LocalizedStringKey("Save as HTML..."))
                        }

                    case .pdf:
                        Button {
                            preparePDFExport()
                        } label: {
                            if isExporting {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(LocalizedStringKey("Save as PDF..."))
                            }
                        }
                        .disabled(isExporting)
                    }
                }
            }
        }
        .frame(minWidth: 740, minHeight: 780)
        .fileExporter(
            isPresented: $showPDFExporter,
            document: ExportPDFDocument(data: pdfData ?? Data()),
            contentType: .pdf,
            defaultFilename: fileName
        ) { result in
            if case .success = result { dismiss() }
            isExporting = false
        }
        .fileExporter(
            isPresented: $showHTMLExporter,
            document: ExportHTMLDocument(data: htmlData ?? Data()),
            contentType: .html,
            defaultFilename: fileName
        ) { result in
            if case .success = result { dismiss() }
        }
        .fileExporter(
            isPresented: $showImageExporter,
            document: ExportImageDocument(data: pngData ?? Data()),
            contentType: .png,
            defaultFilename: "\(fileName)-card"
        ) { result in
            if case .success = result { dismiss() }
            isExporting = false
        }
        .onAppear {
            refreshPreview()
        }
        .onChange(of: mode) { _, _ in
            refreshPreview()
        }
        .onChange(of: selectedStyleRaw) { _, _ in
            cardPreviewImage = nil
            refreshPreview()
        }
        .onChange(of: selectedPaperRaw) { _, _ in
            refreshPreview()
        }
    }

    // MARK: - Refresh & Export Actions

    private func refreshPreview() {
        renderedHTML = ExportService.shared.renderHTML(
            from: text,
            style: selectedStyle,
            theme: activeEditorTheme,
            paperSize: selectedPaper
        )
        if mode == .image && cardPreviewImage == nil {
            generateCardPreview()
        }
    }

    private func generateCardPreview() {
        ExportService.shared.createImage(
            from: text,
            title: fileName,
            style: selectedStyle,
            theme: activeEditorTheme
        ) { result in
            DispatchQueue.main.async {
                if case .success(let image) = result {
                    self.cardPreviewImage = image
                }
            }
        }
    }

    private func preparePDFExport() {
        isExporting = true
        ExportService.shared.createPDF(
            from: text,
            style: selectedStyle,
            theme: activeEditorTheme,
            paperSize: selectedPaper
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.pdfData = data
                    self.showPDFExporter = true
                case .failure(let error):
                    print("PDF Export Error: \(error)")
                    isExporting = false
                }
            }
        }
    }

    private func prepareHTMLExport() {
        let html = ExportService.shared.renderHTML(
            from: text,
            style: selectedStyle,
            theme: activeEditorTheme,
            paperSize: selectedPaper
        )
        self.htmlData = html.data(using: .utf8) ?? Data()
        self.showHTMLExporter = true
    }

    private func prepareImageExport() {
        if let existing = cardPreviewImage,
           let tiff = existing.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:])
        {
            self.pngData = png
            self.showImageExporter = true
            return
        }

        isExporting = true
        ExportService.shared.createImage(
            from: text,
            title: fileName,
            style: selectedStyle,
            theme: activeEditorTheme
        ) { result in
            DispatchQueue.main.async {
                self.isExporting = false
                switch result {
                case .success(let image):
                    self.cardPreviewImage = image
                    if let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:])
                    {
                        self.pngData = png
                        self.showImageExporter = true
                    }
                case .failure(let error):
                    print("Image Export Error: \(error)")
                }
            }
        }
    }

    private func copyImageToClipboard() {
        if let existing = cardPreviewImage {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([existing])
            withAnimation { hasCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { hasCopied = false }
            }
            return
        }

        isExporting = true
        ExportService.shared.createImage(
            from: text,
            title: fileName,
            style: selectedStyle,
            theme: activeEditorTheme
        ) { result in
            DispatchQueue.main.async {
                self.isExporting = false
                if case .success(let image) = result {
                    self.cardPreviewImage = image
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([image])
                    withAnimation { hasCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { hasCopied = false }
                    }
                }
            }
        }
    }
}

// MARK: - Live WYSIWYG WebKit Export Preview

private struct ExportWebPreview: NSViewRepresentable {
    let html: String

    final class Coordinator {
        var lastHTML: String = ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - File Documents

struct ExportPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ExportHTMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.html] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ExportImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
