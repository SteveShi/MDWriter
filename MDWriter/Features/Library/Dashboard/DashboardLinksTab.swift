//
//  DashboardLinksTab.swift
//  MDWriter
//
//  Bi-directional WikiLinks and Backlinks inspector for the Ulysses-style Dashboard.
//

import SwiftData
import SwiftUI

/// Extracted WikiLink reference.
struct WikiLinkItem: Identifiable, Hashable {
    var id: String { rawLink }
    let rawLink: String
    let targetTitle: String
    let alias: String?
}

/// Backlink item representing another note referencing the current note.
struct BacklinkItem: Identifiable {
    var id: PersistentIdentifier { note.persistentModelID }
    let note: Note
    let snippet: String
}

struct DashboardLinksTab: View {
    @Bindable var note: Note
    let text: String
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Note> { !$0.isTrashed })
    private var allNotes: [Note]

    // MARK: - Outgoing Links Extraction

    private var outgoingLinks: [WikiLinkItem] {
        let pattern = #"(?<!\!)\[\[(.*?)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        var items: [WikiLinkItem] = []
        var seen = Set<String>()

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let inner = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty, !seen.contains(inner) else { continue }
            seen.insert(inner)

            if inner.contains("|") {
                let parts = inner.components(separatedBy: "|")
                let target = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let alias = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                items.append(WikiLinkItem(rawLink: inner, targetTitle: target, alias: alias))
            } else {
                items.append(WikiLinkItem(rawLink: inner, targetTitle: inner, alias: nil))
            }
        }

        return items
    }

    // MARK: - Backlinks Extraction

    private var backlinks: [BacklinkItem] {
        guard !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let currentTitleLower = note.title.lowercased()

        var items: [BacklinkItem] = []

        for otherNote in allNotes where otherNote.persistentModelID != note.persistentModelID {
            let content = otherNote.content
            let contentLower = content.lowercased()

            // Check if [[note.title]] or [[note.title|...]] appears in otherNote
            if contentLower.contains("[[\(currentTitleLower)]]") || contentLower.contains("[[\(currentTitleLower)|") {
                // Extract contextual snippet around the mention
                let snippet: String
                if let range = content.range(of: "[[\(note.title)", options: .caseInsensitive) {
                    let start = content.index(range.lowerBound, offsetBy: -40, limitedBy: content.startIndex) ?? content.startIndex
                    let end = content.index(range.upperBound, offsetBy: 80, limitedBy: content.endIndex) ?? content.endIndex
                    snippet = "..." + content[start..<end].replacingOccurrences(of: "\n", with: " ") + "..."
                } else {
                    snippet = String(content.prefix(100))
                }

                items.append(BacklinkItem(note: otherNote, snippet: snippet))
            }
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Backlinks Section
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    Text(LocalizedStringKey("Backlinks"))
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text("\(backlinks.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                if backlinks.isEmpty {
                    Text(LocalizedStringKey("No other notes reference this note yet."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(backlinks) { item in
                            Button {
                                openNote(title: item.note.title)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.accentColor)

                                        Text(item.note.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.primary)

                                        if let folder = item.note.folder {
                                            Text(folder.name)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                    }

                                    Text(item.snippet)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider()

            // MARK: - Outgoing WikiLinks Section
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    Text(LocalizedStringKey("Outgoing Links"))
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text("\(outgoingLinks.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                if outgoingLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("No outgoing WikiLinks found."))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)

                        Text(LocalizedStringKey("Type [[Note Title]] in your writing to connect ideas."))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(outgoingLinks) { link in
                            let existingNote = allNotes.first(where: {
                                $0.title.caseInsensitiveCompare(link.targetTitle) == .orderedSame
                            })

                            HStack(spacing: 8) {
                                Image(systemName: existingNote != nil ? "link" : "link.badge.plus")
                                    .font(.system(size: 11))
                                    .foregroundStyle(existingNote != nil ? Color.accentColor : Color.orange)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(link.targetTitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary)

                                    if let alias = link.alias {
                                        Text("Alias: \(alias)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                if let matched = existingNote {
                                    Button {
                                        openNote(title: matched.title)
                                    } label: {
                                        Text(LocalizedStringKey("Open"))
                                            .font(.system(size: 10.5, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.secondary.opacity(0.08))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button {
                                        createLinkedNote(title: link.targetTitle)
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 9, weight: .bold))
                                            Text(LocalizedStringKey("Create"))
                                                .font(.system(size: 10.5, weight: .medium))
                                        }
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.12))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    private func openNote(title: String) {
        NotificationCenter.default.post(name: Notification.Name("OpenNoteByTitle"), object: title)
    }

    private func createLinkedNote(title: String) {
        let newNote = Note(title: title, content: "# \(title)\n\n", folder: note.folder)
        modelContext.insert(newNote)
        try? modelContext.save()
        openNote(title: title)
    }
}
