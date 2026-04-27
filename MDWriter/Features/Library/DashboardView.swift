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
    #if canImport(FoundationModels)
        case ai = "apple.intelligence"
    #endif

    var id: String { rawValue }
}

struct DashboardView: View {
    @Bindable var note: Note
    @Binding var text: String
    @State private var selectedTab: DashboardTab = .overview
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appTheme") private var currentTheme: AppTheme = .light

    @AppStorage("dashboard.overview.showProgress") private var showProgressInOverview = true
    @AppStorage("dashboard.overview.showKeywords") private var showKeywordsInOverview = true
    @AppStorage("dashboard.overview.showOutline") private var showOutlineInOverview = true
    @AppStorage("dashboard.outline.maxDepth") private var outlineMaxDepth = 6

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(DashboardTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.rawValue)
                                .font(.system(size: 14, weight: .medium))

                            if selectedTab == tab {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(currentTheme.paperColor.opacity(0.3))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch selectedTab {
                        case .overview:
                            OverviewTab(note: note, text: text)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .statistics:
                            StatisticsTab(text: text)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .outline:
                            StructureTab(text: text)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .media:
                            MediaTab(text: text)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        case .notes:
                            NotesTab(note: note)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        #if canImport(FoundationModels)
                            case .ai:
                                if #available(macOS 26.0, *) {
                                    AITab(note: note, text: text)
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                }
                        #endif
                        }
                    }
                    .padding(16)
                }
            }

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
                                Text(LocalizedStringKey("Heading \(level)")).tag(level)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 260)
    }
}
