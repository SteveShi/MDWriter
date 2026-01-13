import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ExportPreviewView: View {
    let text: String
    let fileName: String
    @Environment(\.dismiss) var dismiss
    @State private var isExporting = false
    @State private var showFileExporter = false
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WebView(html: ExportService.shared.renderHTML(from: text))
                    .background(Color(NSColor.windowBackgroundColor))
                    .padding()
            }
            // Hide the default navigation title to make it cleaner
            .navigationTitle("") 
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        prepareExport()
                    } label: {
                        if isExporting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save as PDF...")
                        }
                    }
                    .disabled(isExporting)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .fileExporter(
            isPresented: $showFileExporter,
            document: ExportPDFDocument(data: pdfData ?? Data()),
            contentType: .pdf,
            defaultFilename: fileName
        ) { result in
            if case .success = result {
                dismiss()
            }
            isExporting = false
        }
    }

    private func prepareExport() {
        isExporting = true
        ExportService.shared.createPDF(from: text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.pdfData = data
                    self.showFileExporter = true
                case .failure(let error):
                    print("Export Error: \(error)")
                    isExporting = false
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
