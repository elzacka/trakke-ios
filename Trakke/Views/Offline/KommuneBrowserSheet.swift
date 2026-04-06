import SwiftUI

struct KommuneBrowserSheet: View {
    @Bindable var viewModel: OfflineViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedFylker: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
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
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "offline.choice.kommune"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.kommuneSearchQuery,
                prompt: String(localized: "kommune.search.prompt")
            )
            .onAppear {
                viewModel.loadKommuner()
            }
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
                            ForEach(Array(group.kommuner.enumerated()), id: \.element.id) { index, kommune in
                                Divider().padding(.leading, .Trakke.dividerLeading)
                                NavigationLink {
                                    KommuneDetailView(kommune: kommune, viewModel: viewModel)
                                } label: {
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
        .background(Color(.systemGroupedBackground))
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
