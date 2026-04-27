//
//  DashboardNotesTab.swift
//  MDWriter
//

import SwiftUI

struct NotesTab: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: LocalizedStringKey("Notes"), icon: nil)
                .padding(.bottom, 12)

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

                    DashedLine()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(height: 1)
                        .foregroundColor(.secondary.opacity(0.3))
                        .padding(.vertical, 8)
                }
            }

            Button {
                let newMemo = Memo(content: "", note: note)
                note.memos.append(newMemo)
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
                .frame(minHeight: 40)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(4)

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
