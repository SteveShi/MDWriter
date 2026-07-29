//
//  ChatSearchSourceView.swift
//  MDWriter
//

import SwiftUI

struct ChatSearchSourceView: View {
    let sources: [SearchResult]
    @State private var isExpanded: Bool = false

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                        Text("\(sources.count) Search Sources")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(sources) { source in
                            if let url = URL(string: source.url) {
                                Link(destination: url) {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "link")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(source.title)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Color.accentColor)
                                                .lineLimit(1)
                                            if !source.snippet.isEmpty {
                                                Text(source.snippet)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.leading, 6)
                }
            }
        }
    }
}
