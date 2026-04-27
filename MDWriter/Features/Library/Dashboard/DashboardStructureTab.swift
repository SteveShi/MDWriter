//
//  DashboardStructureTab.swift
//  MDWriter
//

import SwiftUI

struct StructureTab: View {
    var text: String
    @AppStorage("dashboard.outline.maxDepth") private var maxDepth = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: LocalizedStringKey("Outline"), icon: nil)

            let headers = MDHeaderParser.parseHeaders(from: text).filter { $0.level <= maxDepth }

            if headers.isEmpty {
                Text(LocalizedStringKey("No Structure"))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(headers) { header in
                    HStack {
                        ForEach(0..<max(0, header.level - 1), id: \.self) { _ in
                            Spacer().frame(width: 12)
                        }

                        Text(header.title)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
