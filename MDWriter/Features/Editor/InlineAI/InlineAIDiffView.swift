//
//  InlineAIDiffView.swift
//  MDWriter
//
//  Unified and Side-by-Side inline diff review components with Accept/Reject controls.
//

import SwiftUI

/// Represents a single line entry in a unified diff review.
enum DiffLineType: Equatable, Sendable {
    case unchanged
    case deleted
    case inserted
}

struct DiffLineItem: Identifiable, Equatable, Sendable {
    let id: UUID = UUID()
    let type: DiffLineType
    let text: String
}

/// Helper to compute line-level diff items between old text and new text.
enum InlineDiffCalculator {
    static func computeLines(original: String, modified: String) -> [DiffLineItem] {
        let oldLines = original.components(separatedBy: .newlines)
        let newLines = modified.components(separatedBy: .newlines)

        let diff = newLines.difference(from: oldLines)

        var result: [DiffLineItem] = []
        var oldIndex = 0
        var newIndex = 0

        // Use standard two-pointer with difference tracking
        let removals = Set(diff.removals.compactMap { change -> Int? in
            if case let .remove(offset, _, _) = change { return offset }
            return nil
        })
        let insertions = Set(diff.insertions.compactMap { change -> Int? in
            if case let .insert(offset, _, _) = change { return offset }
            return nil
        })

        while oldIndex < oldLines.count || newIndex < newLines.count {
            if removals.contains(oldIndex) {
                result.append(DiffLineItem(type: .deleted, text: oldLines[oldIndex]))
                oldIndex += 1
            } else if insertions.contains(newIndex) {
                result.append(DiffLineItem(type: .inserted, text: newLines[newIndex]))
                newIndex += 1
            } else if oldIndex < oldLines.count && newIndex < newLines.count {
                result.append(DiffLineItem(type: .unchanged, text: oldLines[oldIndex]))
                oldIndex += 1
                newIndex += 1
            } else if oldIndex < oldLines.count {
                result.append(DiffLineItem(type: .deleted, text: oldLines[oldIndex]))
                oldIndex += 1
            } else if newIndex < newLines.count {
                result.append(DiffLineItem(type: .inserted, text: newLines[newIndex]))
                newIndex += 1
            }
        }

        return result
    }
}

/// Inline diff review panel showing colored deletions, insertions, and action buttons.
struct InlineAIDiffView: View {
    let originalText: String
    let modifiedText: String
    let onAccept: () -> Void
    let onReject: () -> Void
    let onRetry: () -> Void

    @State private var showSideBySide: Bool = false

    private var diffLines: [DiffLineItem] {
        InlineDiffCalculator.computeLines(original: originalText, modified: modifiedText)
    }

    private var statsSummary: (origWords: Int, modWords: Int, diffWords: Int) {
        let origWords = originalText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let modWords = modifiedText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return (origWords, modWords, modWords - origWords)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.outline")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 13, weight: .semibold))

                Text(LocalizedStringKey("Review AI Suggestions"))
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                // Word count delta badge
                let stats = statsSummary
                HStack(spacing: 4) {
                    Text("\(stats.origWords)w")
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text("\(stats.modWords)w")
                        .foregroundStyle(.primary)

                    if stats.diffWords != 0 {
                        Text("(\(stats.diffWords > 0 ? "+\(stats.diffWords)" : "\(stats.diffWords)"))")
                            .foregroundStyle(stats.diffWords > 0 ? Color.green : Color.red)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())

                // Toggle View Mode
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSideBySide.toggle()
                    }
                } label: {
                    Image(systemName: showSideBySide ? "rectangle.split.2x1" : "rectangle.stack")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(LocalizedStringKey("Toggle Diff View"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.04))

            Divider()

            // Diff Scroll Body
            ScrollView(.vertical) {
                if showSideBySide {
                    sideBySideView
                } else {
                    unifiedDiffView
                }
            }
            .frame(maxHeight: 280)

            Divider()

            // Footer action buttons
            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(modifiedText, forType: .string)
                } label: {
                    Label(LocalizedStringKey("Copy"), systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(LocalizedStringKey("Copy suggested text"))

                Button {
                    onRetry()
                } label: {
                    Label(LocalizedStringKey("Retry"), systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("r", modifiers: .command)
                .help(LocalizedStringKey("Retry generation (⌘R)"))

                Spacer()

                Button {
                    onReject()
                } label: {
                    Text(LocalizedStringKey("Reject (Esc)"))
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    onAccept()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(LocalizedStringKey("Accept (⏎)"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.03))
        }
    }

    // MARK: - Unified View

    private var unifiedDiffView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(diffLines) { item in
                HStack(alignment: .top, spacing: 6) {
                    Group {
                        switch item.type {
                        case .unchanged:
                            Text("  ")
                                .foregroundStyle(.tertiary)
                        case .deleted:
                            Text("- ")
                                .foregroundStyle(.red)
                                .fontWeight(.bold)
                        case .inserted:
                            Text("+ ")
                                .foregroundStyle(.green)
                                .fontWeight(.bold)
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 16, alignment: .trailing)

                    Text(item.text.isEmpty ? " " : item.text)
                        .font(.system(size: 12.5, design: .monospaced))
                        .strikethrough(item.type == .deleted, color: .red)
                        .foregroundStyle(item.type == .deleted ? Color.red.opacity(0.8) : (item.type == .inserted ? Color.green : Color.primary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    item.type == .deleted
                        ? Color.red.opacity(0.08)
                        : (item.type == .inserted ? Color.green.opacity(0.10) : Color.clear)
                )
                .cornerRadius(4)
            }
        }
        .padding(10)
    }

    // MARK: - Side by Side View

    private var sideBySideView: some View {
        HStack(alignment: .top, spacing: 10) {
            // Original Column
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey("Original"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(originalText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
            }
            .frame(maxWidth: .infinity)

            // Suggested Column
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey("Suggested"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .textCase(.uppercase)

                Text(modifiedText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(6)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
    }
}
