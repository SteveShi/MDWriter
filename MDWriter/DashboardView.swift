//
//  DashboardView.swift
//  MDWriter
//
//  Ulysses-style Dashboard Panel
//  Replaces the simple outline view with a comprehensive toolset.
//

import SwiftData
import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "square.grid.2x2"
    case statistics = "chart.xyaxis.line"
    case outline = "list.bullet"
    case media = "photo.on.rectangle"
    case notes = "text.bubble"

    var id: String { rawValue }
}

struct DashboardView: View {
    @Bindable var note: Note
    @Binding var text: String  // Need binding to text for realtime updates
    @State private var selectedTab: DashboardTab = .overview
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Top Tab Bar
            HStack(spacing: 0) {
                ForEach(DashboardTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Check/Status Icon (Visual only for now, mirroring Ulysses)
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 32)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content Area
            ZStack {
                Color(nsColor: .windowBackgroundColor).opacity(0.5)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .overview:
                            OverviewTab(note: note, text: text)
                        case .statistics:
                            StatisticsTab(text: text)
                        case .outline:
                            StructureTab(text: text)
                        case .media:
                            MediaTab(text: text)
                        case .notes:
                            NotesTab(note: note)
                        }
                    }
                    .padding()
                }
            }

            // Bottom Toolbar (Configuration)
            Divider()
            HStack {
                Spacer()
                Menu {
                    switch selectedTab {
                    case .overview:
                        Toggle(LocalizedStringKey("Progress"), isOn: $showProgressInOverview)
                        Toggle(LocalizedStringKey("Keywords"), isOn: $showKeywordsInOverview)
                        Toggle(LocalizedStringKey("Outline"), isOn: $showOutlineInOverview)
                    case .statistics:
                        Text(LocalizedStringKey("Statistics Configuration (None)"))
                    case .outline:
                        Text(LocalizedStringKey("Display Levels"))
                        Picker(LocalizedStringKey("Levels"), selection: $outlineMaxDepth) {
                            ForEach(1...6, id: \.self) { level in
                                Text("Heading \(level)").tag(level)
                            }
                        }
                    default:
                        Text(LocalizedStringKey("No Configuration Options"))
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 250)
    }

    // Configuration States (Shared with subviews via AppStorage)
    @AppStorage("dashboard.overview.showProgress") private var showProgressInOverview = true
    @AppStorage("dashboard.overview.showKeywords") private var showKeywordsInOverview = true
    @AppStorage("dashboard.overview.showOutline") private var showOutlineInOverview = true
    @AppStorage("dashboard.outline.maxDepth") private var outlineMaxDepth = 6
}

// MARK: - 1. Overview Tab

struct OverviewTab: View {
    @Bindable var note: Note
    var text: String

    @AppStorage("dashboard.overview.showProgress") private var showProgress = true
    @AppStorage("dashboard.overview.showKeywords") private var showKeywords = true
    @AppStorage("dashboard.overview.showOutline") private var showOutline = true

    // Derived stats
    private var stats: DocumentStatistics {
        DocumentStatistics.calculate(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Progress Section
            if showProgress {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: LocalizedStringKey("Progress"), icon: "target")

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
                                "\(stats.readingTime) \(NSLocalizedString("Seconds", comment: ""))")
                        Spacer()
                    }
                }
                Divider().opacity(0.5)
            }

            // Keywords Section
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

                    // Simple input for demo
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

            // Outline Section (Preview)
            if showOutline {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: LocalizedStringKey("Outline"), icon: nil)

                    let headers = MDHeaderParser.parseHeaders(from: text)
                    if let first = headers.first {
                        HStack {
                            Image(systemName: "circle")  // Placeholder for hierarchy icon
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
    }
}

// MARK: - 2. Statistics Tab

struct StatisticsTab: View {
    var text: String

    private var stats: DocumentStatistics {
        DocumentStatistics.calculate(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Counters
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: LocalizedStringKey("Counters"), icon: "target")

                StatRow(label: LocalizedStringKey("Characters"), value: "\(stats.characters)")
                StatRow(
                    label: LocalizedStringKey("Excluding spaces"),
                    value: "\(stats.characters - text.filter { $0.isWhitespace }.count)")
                StatRow(label: LocalizedStringKey("Words"), value: "\(stats.words)")
                StatRow(
                    label: LocalizedStringKey("Sentences"),
                    value: "\(text.components(separatedBy: ".").count - 1)")  // Rough estimate
                StatRow(
                    label: LocalizedStringKey("Paragraphs"),
                    value: "\(text.components(separatedBy: "\n\n").count)")
                StatRow(label: LocalizedStringKey("Per line"), value: "2")  // Placeholder
                StatRow(label: LocalizedStringKey("Pages"), value: "0.1")  // Placeholder
            }

            Divider().opacity(0.5)

            // Reading Time
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: LocalizedStringKey("Reading Time"), icon: "clock")

                StatRow(
                    label: LocalizedStringKey("Slow"),
                    value: "\(stats.readingTime + 1) \(NSLocalizedString("Seconds", comment: ""))")
                StatRow(
                    label: LocalizedStringKey("Average"),
                    value: "\(stats.readingTime) \(NSLocalizedString("Seconds", comment: ""))")
                StatRow(
                    label: LocalizedStringKey("Fast"),
                    value:
                        "\(max(0, stats.readingTime - 1)) \(NSLocalizedString("Seconds", comment: ""))"
                )
            }
        }
    }
}

// MARK: - 3. Structure Tab (Outline)

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
                        // Indentation
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

// MARK: - 4. Media Tab

struct MediaTab: View {
    var text: String

    // Extract image URLs/Filenames using Regex
    private var images: [String] {
        let pattern = #"!\[.*?\]\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = text as NSString
        let results = regex.matches(
            in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        return results.map { nsString.substring(with: $0.range(at: 1)) }
    }

    // Resolve URL (local or remote)
    private func resolveURL(for path: String) -> URL? {
        if path.lowercased().hasPrefix("http") {
            return URL(string: path)
        } else {
            return ImageManager.shared.fileURL(for: path)
        }
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
                                // 网络图片使用 AsyncImage
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
                                // 本地图片使用 ImageManager 加载
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

// MARK: - 5. NotesTab

struct NotesTab: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: LocalizedStringKey("Notes"), icon: nil)
                .padding(.bottom, 12)

            if note.memos.isEmpty {
                // Empty state handled naturally by the Add button below,
                // but can add a placeholder if desired.
            }

            // List of Memos
            ForEach(note.memos.sorted(by: { $0.createdAt < $1.createdAt })) { memo in
                VStack(spacing: 0) {
                    MemoRow(
                        memo: memo,
                        onDelete: {
                            if let index = note.memos.firstIndex(of: memo) {
                                note.memos.remove(at: index)
                                modelContext.delete(memo)
                            }
                        })

                    // Dashed Separator
                    DashedLine()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                        .padding(.vertical, 8)
                }
            }

            // Add Button
            Button {
                let newMemo = Memo(content: "", note: note)
                note.memos.append(newMemo)
                // Auto-save happens via modelContext
            } label: {
                Text(LocalizedStringKey("Add..."))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

struct MemoRow: View {
    @Bindable var memo: Memo
    var onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $memo.content)
                .font(.system(size: 13))
                .frame(minHeight: 40)  // Minimum height
                .scrollContentBackground(.hidden)  // Remove default background
                .background(Color.clear)
                .padding(4)

            // Delete button (visible on hover)
            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .onHover { hover in
            isHovering = hover
        }
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}

// MARK: - Shared Components

struct SectionHeader: View {
    let title: LocalizedStringKey
    let icon: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatCompactRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.9))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

struct StatRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// Flow layout implemented via the Layout protocol to avoid Sendable warnings.
struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    var body: some View {
        FlowLayoutLayout {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding([.horizontal, .vertical], 4)
            }
        }
    }
}

struct FlowLayoutLayout: Layout {
    private let horizontalSpacing: CGFloat = 0
    private let verticalSpacing: CGFloat = 0

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            maxX = max(maxX, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }

        let totalHeight = y + rowHeight
        return CGSize(width: maxX, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
        }
    }
}
