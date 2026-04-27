//
//  DashboardStatisticsTab.swift
//  MDWriter
//

import SwiftUI

struct StatisticsTab: View {
    var text: String

    private var stats: DocumentStatistics {
        DocumentStatistics.calculate(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: LocalizedStringKey("Counters"), icon: "target")

                StatRow(label: LocalizedStringKey("Characters"), value: "\(stats.characters)")
                StatRow(
                    label: LocalizedStringKey("Excluding spaces"),
                    value: "\(stats.characters - text.filter { $0.isWhitespace }.count)")
                StatRow(label: LocalizedStringKey("Words"), value: "\(stats.words)")
                StatRow(
                    label: LocalizedStringKey("Sentences"),
                    value: "\(text.components(separatedBy: ".").count - 1)")
                StatRow(
                    label: LocalizedStringKey("Paragraphs"),
                    value: "\(text.components(separatedBy: "\n\n").count)")
                StatRow(label: LocalizedStringKey("Per line"), value: "2")
                StatRow(label: LocalizedStringKey("Pages"), value: "0.1")
            }

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: LocalizedStringKey("Reading Time"), icon: "clock")

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
            }
        }
    }
}
