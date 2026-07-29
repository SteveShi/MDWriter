//
//  ChatToolResultView.swift
//  MDWriter
//

import SwiftUI

struct ChatToolResultView: View {
    let toolName: String?
    let content: String
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)

                    Text(toolDisplayName)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(6)
            }
        }
    }

    private var toolDisplayName: String {
        guard let name = toolName else { return "Tool Execution" }
        if name.hasPrefix("mcp_") {
            let parts = name.split(separator: "_")
            if parts.count >= 3 {
                return "MCP: \(parts[1])/\(parts[2])"
            }
        }
        return "Tool: \(name)"
    }
}
