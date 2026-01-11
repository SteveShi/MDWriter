//
//  MDWriterDocument.swift
//  MDWriter
//
//  Created by Gemini on 2026/01/11.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var markdownDocument: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

struct MDWriterDocument: FileDocument {
    var text: String

    init(text: String = "# Welcome to MDWriter\n\nStart typing on the left...") {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

