import SwiftUI

// MARK: - Tab Identitet

private enum OfflineSetupTab: Hashable, CaseIterable, Identifiable {
    case custom
    case kommune

    var id: Self { self }

    var localizedTitle: String {
        switch self {
        case .custom: return String(localized: "offline.choice.custom")
        case .kommune: return String(localized: "offline.choice.kommune")
        }
    }
}

// MARK: - OfflineSetupSheet

/// Konsolidert flate for å starte nedlasting av et offline-kartområde.
/// Erstatter OfflineChoiceSheet og KommuneBrowserSheet — to flater er
/// nå én sheet med segmenter. KommuneDetailView pushes fortsatt via
/// NavigationStack.
struct OfflineSetupSheet: View {
    @Bindable var viewModel: OfflineViewModel
    var onCustom: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: OfflineSetupTab = .custom
    @State private var expandedFylker: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(OfflineSetupTab.allCases) { tab in
                        Text(tab.localizedTitle).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.vertical, .Trakke.sm)

                Group {
                    switch selectedTab {
                    case .custom: customContent
                    case .kommune: kommuneContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "offline.choice.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: KommuneRegion.self) { kommune in
                KommuneDetailView(kommune: kommune, viewModel: viewModel)
            }
            .searchable(
                text: $viewModel.kommuneSearchQuery,
                prompt: String(localized: "kommune.search.prompt")
            )
            .searchSuggestions {}
            .onAppear {
                if selectedTab == .kommune {
                    viewModel.loadKommuner()
                }
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == .kommune {
                    viewModel.loadKommuner()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Tab: Egendefinert

    private var customContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection {
                    VStack(alignment: .leading, spacing: .Trakke.md) {
                        Text(String(localized: "offline.choice.custom.subtitle"))
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            dismiss()
                            onCustom()
                        } label: {
                            Label(
                                String(localized: "offline.selectArea"),
                                systemImage: "rectangle.dashed"
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.trakkePrimary)
                    }
                    .padding(.vertical, .Trakke.sm)
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
    }

    // MARK: - Tab: Kommune

    @ViewBuilder
    private var kommuneContent: some View {
        if viewModel.kommuner.isEmpty {
            EmptyStateView(
                icon: "mappin.slash",
                title: String(localized: "kommune.empty.title"),
                subtitle: String(localized: "kommune.empty.subtitle")
            )
        } else if viewModel.filteredKommuner.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: String(localized: "kommune.noResults.title"),
                subtitle: String(localized: "kommune.noResults.subtitle")
            )
        } else {
            kommuneList
        }
    }

    private var kommuneList: some View {
        ScrollView {
            VStack(spacing: .Trakke.sm) {
                ForEach(viewModel.kommunerByFylke, id: \.fylke) { group in
                    let isExpanded = !viewModel.kommuneSearchQuery.isEmpty || expandedFylker.contains(group.fylke)
                    CardSection {
                        Button {
                            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                                if expandedFylker.contains(group.fylke) {
                                    expandedFylker.remove(group.fylke)
                                } else {
                                    expandedFylker.insert(group.fylke)
                                }
                            }
                        } label: {
                            HStack {
                                Text(group.fylke)
                                    .font(Font.Trakke.bodyMedium)
                                    .foregroundStyle(Color.Trakke.text)
                                Spacer()
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(Font.Trakke.captionSoft)
                                    .foregroundStyle(Color.Trakke.textTertiary)
                            }
                            .padding(.vertical, .Trakke.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(group.fylke)
                        .accessibilityHint(isExpanded
                            ? String(localized: "accessibility.tapToCollapse")
                            : String(localized: "accessibility.tapToExpand"))

                        if isExpanded {
                            ForEach(Array(group.kommuner.enumerated()), id: \.element.id) { _, kommune in
                                Divider().padding(.leading, .Trakke.dividerLeading)
                                NavigationLink(value: kommune) {
                                    kommuneRow(kommune)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
    }

    private func kommuneRow(_ kommune: KommuneRegion) -> some View {
        HStack {
            Text(kommune.name)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.text)

            Spacer()

            if viewModel.isKommuneDownloaded(kommune) {
                Image(systemName: "checkmark.circle.fill")
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.brand)
            } else {
                let maxZoom = kommune.optimalMaxZoom()
                let tiles = kommune.estimatedTileCount(minZoom: 8, maxZoom: maxZoom)
                let size = OfflineMapService.formatBytes(OfflineMapService.estimateSize(tileCount: tiles))
                Text(size)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .padding(.horizontal, .Trakke.badgePadH)
                    .padding(.vertical, .Trakke.badgePadV)
                    .background(Color.Trakke.brandTint)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.vertical, .Trakke.xs)
        .contentShape(Rectangle())
        .accessibilityLabel(kommune.name)
    }
}
