import SwiftUI

struct OverviewTab: View {
    @Bindable var note: Note
    var text: String

    @AppStorage("dashboard.overview.showProgress") private var showProgress = true
    @AppStorage("dashboard.overview.showKeywords") private var showKeywords = true
    @AppStorage("dashboard.overview.showOutline") private var showOutline = true

    @State private var stats: DocumentStatistics?
    @State private var firstHeader: DocumentHeader?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            if showProgress {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: LocalizedStringKey("Progress"), icon: "target")

                    if let stats = stats {
                        HStack {
                            StatCompactRow(
                                label: LocalizedStringKey("Characters"), value: "\(stats.characters)")
                            Spacer()
                        }
                        HStack {
                            StatCompactRow(label: LocalizedStringKey("Words"), value: "\(stats.words)")
                            Spacer()
                        }
                        HStack {
                            StatCompactRow(
                                label: LocalizedStringKey("Average"),
                                value:
                                    "\(stats.readingTime) \(String(localized: "Seconds"))")
                            Spacer()
                        }
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                Divider().opacity(0.5)
            }

            if showKeywords {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: LocalizedStringKey("Keywords"), icon: "plus.circle")

                    if note.tags.isEmpty {
                        Text(LocalizedStringKey("Add Keyword"))
                            .foregroundColor(.secondary.opacity(0.7))
                            .font(.system(size: 13))
                            .padding(.vertical, 4)
                    } else {
                        FlowLayout(items: note.tags) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button {
                                    if let index = note.tags.firstIndex(of: tag) {
                                        note.tags.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.accentColor)
                        }
                    }

                    TextField(
                        LocalizedStringKey("Type and press Enter to add..."),
                        text: Binding(
                            get: { "" },
                            set: { newVal in
                                if !newVal.isEmpty {
                                    note.tags.append(newVal)
                                }
                            }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        // Logic handled in binding set
                    }
                }
                Divider().opacity(0.5)
            }

            if showOutline {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: LocalizedStringKey("Outline"), icon: nil)

                    if let first = firstHeader {
                        HStack {
                            Image(systemName: "circle")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text(first.title)
                                .font(.system(size: 13))
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    } else {
                        Text(LocalizedStringKey("No outline content"))
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .task(id: text) {
            // 后台计算统计信息和第一个标题
            let result = await Task.detached {
                let newStats = DocumentStatistics.calculate(from: text)
                let headers = MDHeaderParser.parseHeaders(from: text)
                return (newStats, headers.first)
            }.value

            stats = result.0
            firstHeader = result.1
        }
    }
}
