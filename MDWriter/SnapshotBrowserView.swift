//
//  SnapshotBrowserView.swift
//  MDWriter
//
//  Created for v1.7.0
//

import SwiftData
import SwiftUI

struct SnapshotBrowserView: View {
    let note: Note
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

    // Sort snapshots by creation date descending
    var sortedSnapshots: [Snapshot] {
        note.snapshots.sorted(by: { $0.createdAt > $1.createdAt })
    }

    @State private var selectedSnapshot: Snapshot?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSnapshot) {
                if sortedSnapshots.isEmpty {
                    Text(LocalizedStringKey("No versions saved"))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(sortedSnapshots) { snapshot in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(snapshot.createdAt, style: .date)
                                    .font(.headline)
                                Text(snapshot.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(snapshot.content.count) " + String(localized: "chars"))
                                .font(.caption)
                                .foregroundColor(.tertiaryLabel)
                        }
                        .tag(snapshot)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Versions"))
            .listStyle(.sidebar)
        } detail: {
            if let snapshot = selectedSnapshot {
                VStack(spacing: 0) {
                    ScrollView {
                        Text(snapshot.content)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            modelContext.delete(snapshot)
                            try? modelContext.save()
                            if selectedSnapshot == snapshot {
                                selectedSnapshot = nil
                            }
                        } label: {
                            Label(LocalizedStringKey("Delete Version"), systemImage: "trash")
                        }

                        Button {
                            restore(snapshot)
                        } label: {
                            Label(
                                LocalizedStringKey("Restore to this Version"),
                                systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            } else {
                ContentUnavailableView(String(localized: "Select a version"), systemImage: "clock")
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Close")) {
                    isPresented = false
                }
            }
        }
    }

    private func restore(_ snapshot: Snapshot) {
        // 1. Create a safety snapshot of the CURRENT state
        let safetySnapshot = Snapshot(content: note.content, note: note)
        modelContext.insert(safetySnapshot)

        // 2. Restore content
        note.content = snapshot.content
        note.modifiedAt = Date()

        try? modelContext.save()
        isPresented = false
    }
}

#if os(macOS)
    extension Color {
        // Already defined in LibraryView if not globally
        // But since this is a new file, we can rely on standard SwiftUI colors
        // or assume the extension is accessible if it's in the same target.
        // If not, we might need to add it or use platform conditional.
    }
#endif
