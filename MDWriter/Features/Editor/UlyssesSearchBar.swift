import SwiftUI

struct UlyssesSearchBar: View {
    @ObservedObject var controller: EditorController
    @FocusState private var isFindFocused: Bool
    @FocusState private var isReplaceFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Find Row
            HStack(spacing: 12) {
                // Find Input with Nav Arrows
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))

                    TextField(LocalizedStringKey("Find"), text: $controller.searchText)
                        .textFieldStyle(.plain)
                        .focused($isFindFocused)
                        .font(.system(size: 13))
                        .onSubmit {
                            controller.findNext()
                        }

                    HStack(spacing: 12) {
                        Button(action: { controller.findPrevious() }) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)

                        Button(action: { controller.findNext() }) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.secondary)
                    .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.15))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .frame(width: 320)

                Toggle(
                    LocalizedStringKey("Replace"),
                    isOn: $controller.isReplaceVisible.animation(
                        .spring(response: 0.35, dampingFraction: 0.8))
                )
                .toggleStyle(.checkbox)
                .font(.system(size: 13))
            }

            // Row 2: Replace Row
            if controller.isReplaceVisible {
                HStack(spacing: 12) {
                    TextField(LocalizedStringKey("Replace"), text: $controller.replaceText)
                        .textFieldStyle(.plain)
                        .focused($isReplaceFocused)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.15))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                        .frame(width: 320)
                        .onSubmit {
                            controller.replace()
                        }

                    HStack(spacing: 8) {
                        SearchActionButton(title: "Replace", action: controller.replace)
                        SearchActionButton(title: "All", action: controller.replaceAll)
                        SearchActionButton(
                            title: "Done",
                            action: {
                                withAnimation {
                                    controller.isSearchVisible = false
                                }
                            }, isProminent: true)
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if !controller.isReplaceVisible {
                // Done button when search only
                HStack {
                    Spacer()
                    SearchActionButton(
                        title: "Done",
                        action: {
                            withAnimation {
                                controller.isSearchVisible = false
                            }
                        }, isProminent: true)
                }
                .frame(width: 320 + 12 + 20)  // Match the alignment of the replace row
                .offset(x: -30)  // Optical adjustment to center the whole unit
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            isFindFocused = true
        }
    }
}

// MARK: - Subviews

struct SearchActionButton: View {
    let title: String
    let action: () -> Void
    var isProminent: Bool = false

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isProminent ? Color.accentColor : Color.white.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
