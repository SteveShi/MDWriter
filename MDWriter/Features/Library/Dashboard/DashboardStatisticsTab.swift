import SwiftUI

struct StatisticsTab: View {
    var text: String

    @State private var stats: DocumentStatistics?
    @State private var spacesCount: Int = 0
    @State private var sentencesCount: Int = 0
    @State private var paragraphsCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: LocalizedStringKey("Counters"), icon: "target")

                if let stats = stats {
                    StatRow(label: LocalizedStringKey("Characters"), value: "\(stats.characters)")
                    StatRow(
                        label: LocalizedStringKey("Excluding spaces"),
                        value: "\(stats.characters - spacesCount)")
                    StatRow(label: LocalizedStringKey("Words"), value: "\(stats.words)")
                    StatRow(
                        label: LocalizedStringKey("Sentences"),
                        value: "\(sentencesCount)")
                    StatRow(
                        label: LocalizedStringKey("Paragraphs"),
                        value: "\(paragraphsCount)")
                    StatRow(label: LocalizedStringKey("Per line"), value: "2")
                    StatRow(label: LocalizedStringKey("Pages"), value: "0.1")
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: LocalizedStringKey("Reading Time"), icon: "clock")

                if let stats = stats {
                    StatRow(
                        label: LocalizedStringKey("Slow"),
                        value: "\(stats.readingTime + 1) \(String(localized: "Seconds"))")
                    StatRow(
                        label: LocalizedStringKey("Average"),
                        value: "\(stats.readingTime) \(String(localized: "Seconds"))")
                    StatRow(
                        label: LocalizedStringKey("Fast"),
                        value:
                            "\(max(0, stats.readingTime - 1)) \(String(localized: "Seconds"))"
                    )
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .task(id: text) {
            // 后台计算统计信息
            let result = await Task.detached {
                let newStats = DocumentStatistics.calculate(from: text)
                let spaces = text.filter { $0.isWhitespace }.count
                let sentences = text.components(separatedBy: ".").count - 1
                let paragraphs = text.components(separatedBy: "\n\n").count
                return (newStats, spaces, sentences, paragraphs)
            }.value

            stats = result.0
            spacesCount = result.1
            sentencesCount = result.2
            paragraphsCount = result.3
        }
    }
}
