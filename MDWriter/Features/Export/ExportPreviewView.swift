//
//  ExportPreviewView.swift
//  MDWriter
//

import AppKit
import Foundation
import MDEditorKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

enum ExportPreviewMode: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case image = "Social Card"

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .pdf: return LocalizedStringKey("PDF Document")
        case .image: return LocalizedStringKey("Social Card (Image)")
        }
    }
}

struct ExportPreviewView: View {
    let text: String
    let fileName: String
    @Environment(\.dismiss) var dismiss

    @State private var mode: ExportPreviewMode = .pdf
    @State private var isExporting = false
    @State private var showPDFExporter = false
    @State private var showImageExporter = false
    @State private var pdfData: Data?
    @State private var pngData: Data?
    @State private var cardPreviewImage: NSImage?
    @State private var hasCopied = false

    @ObservedObject private var editorSettings = EditorSettings.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Selector Bar
                Picker("", selection: $mode) {
                    ForEach(ExportPreviewMode.allCases) { m in
                        Text(m.localizedName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                Divider()

                // Content Preview Area
                Group {
                    if mode == .pdf {
                        ScrollView {
                            MarkdownViewWrapper(
                                text: text,
                                configuration: editorSettings.configuration
                            )
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(32)
                        }
                        .background(Color(NSColor.windowBackgroundColor))
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
                    if mode == .image {
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
                    } else {
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
        .frame(minWidth: 640, minHeight: 740)
        .fileExporter(
            isPresented: $showPDFExporter,
            document: ExportPDFDocument(data: pdfData ?? Data()),
            contentType: .pdf,
            defaultFilename: fileName
        ) { result in
            if case .success = result {
                dismiss()
            }
            isExporting = false
        }
        .fileExporter(
            isPresented: $showImageExporter,
            document: ExportImageDocument(data: pngData ?? Data()),
            contentType: .png,
            defaultFilename: "\(fileName)-card"
        ) { result in
            if case .success = result {
                dismiss()
            }
            isExporting = false
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .image && cardPreviewImage == nil {
                generateCardPreview()
            }
        }
        .onAppear {
            if mode == .image {
                generateCardPreview()
            }
        }
    }

    private func generateCardPreview() {
        let storedThemeID = UserDefaults.standard.string(forKey: "markdownTheme")
        let theme = storedThemeID.flatMap(MarkdownTheme.init(rawValue:)) ?? .pure

        ExportService.shared.createImage(from: text, title: fileName, theme: theme) { result in
            DispatchQueue.main.async {
                if case .success(let image) = result {
                    self.cardPreviewImage = image
                }
            }
        }
    }

    private func preparePDFExport() {
        isExporting = true
        ExportService.shared.createPDF(from: text) { result in
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

    private func prepareImageExport() {
        if let existing = cardPreviewImage,
           let tiff = existing.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            self.pngData = png
            self.showImageExporter = true
            return
        }

        isExporting = true
        let storedThemeID = UserDefaults.standard.string(forKey: "markdownTheme")
        let theme = storedThemeID.flatMap(MarkdownTheme.init(rawValue:)) ?? .pure

        ExportService.shared.createImage(from: text, title: fileName, theme: theme) { result in
            DispatchQueue.main.async {
                self.isExporting = false
                switch result {
                case .success(let image):
                    self.cardPreviewImage = image
                    if let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
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
        let storedThemeID = UserDefaults.standard.string(forKey: "markdownTheme")
        let theme = storedThemeID.flatMap(MarkdownTheme.init(rawValue:)) ?? .pure

        ExportService.shared.createImage(from: text, title: fileName, theme: theme) { result in
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

// MARK: - PDF Document Wrapper
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
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Image Document Wrapper
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
        return FileWrapper(regularFileWithContents: data)
    }
}
