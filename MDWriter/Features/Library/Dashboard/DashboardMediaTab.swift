//
//  DashboardMediaTab.swift
//  MDWriter
//

import SwiftUI

struct MediaTab: View {
    var text: String

    private var images: [String] {
        let pattern = #"!\[.*?\]\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = text as NSString
        let results = regex.matches(
            in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        return results.map { nsString.substring(with: $0.range(at: 1)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: LocalizedStringKey("Media"), icon: nil)

            if images.isEmpty {
                VStack(spacing: 12) {
                    Text(LocalizedStringKey("No Images"))
                        .foregroundColor(.secondary)
                    Text(LocalizedStringKey("Images"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                    ForEach(images, id: \.self) { imagePath in
                        Group {
                            if imagePath.lowercased().hasPrefix("http") {
                                if let url = URL(string: imagePath) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image.resizable().aspectRatio(contentMode: .fit)
                                        case .failure:
                                            Image(systemName: "photo")
                                                .foregroundColor(.secondary)
                                                .frame(height: 50)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                if let nsImage = ImageManager.shared.loadImage(named: imagePath) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                        .frame(height: 50)
                                }
                            }
                        }
                        .frame(height: 80)
                        .cornerRadius(6)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            Divider().padding(.vertical, 8)

            Text(LocalizedStringKey("Use ⌘ + I or drag and drop to insert images"))
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
        }
    }
}
