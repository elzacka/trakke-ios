import SwiftUI

/// Konsolidert flate for å starte nedlasting av et offline-kartområde.
/// Én sammenhengende liste i Tråkkes menyvalg-standard: én rad for å tegne
/// eget område på kartet, og kommune-tre under (alfabetisk per fylke).
/// KommuneDetailView pushes via parent NavigationStack når en kommune velges.
struct OfflineSetupSheet: View {
    @Bindable var viewModel: OfflineViewModel
    var onCustom: () -> Void
    /// Inline-modus: ingen NavigationStack/title/presentationDetents — kalleren
    /// (f.eks. Verktøy-fanen) gir sin egen NavigationStack og sheet-kontekst.
    var inline = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedFylker: Set<String> = []

    var body: some View {
        if inline {
            innerContent
        } else {
            NavigationStack {
                innerContent
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var innerContent: some View {
        scrollableContent
            .background(Color.Trakke.background)
            .tint(Color.Trakke.brand)
            .navigationTitle(inline ? "" : String(localized: "offline.choice.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(inline ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: KommuneRegion.self) { kommune in
                KommuneDetailView(kommune: kommune, viewModel: viewModel)
            }
            .searchable(
                text: $viewModel.kommuneSearchQuery,
                prompt: String(localized: "kommune.search.prompt")
            )
            .searchSuggestions {}
            .onAppear {
                viewModel.loadKommuner()
            }
    }

    private var scrollableContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                // Tegn eget område på kartet
                CardSection(String(localized: "offline.choice.custom")) {
                    TrakkeMenuRow(
                        label: String(localized: "offline.selectArea"),
                        action: {
                            dismiss()
                            onCustom()
                        }
                    )
                }

                // Kommune-tre per fylke
                kommuneSection
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
            .padding(.bottom, .Trakke.xxl)
        }
    }

    @ViewBuilder
    private var kommuneSection: some View {
        if !viewModel.kommuner.isEmpty {
            if viewModel.filteredKommuner.isEmpty {
                CardSection {
                    Text(String(localized: "kommune.noResults.title"))
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, .Trakke.sm)
                }
            } else {
                ForEach(Array(viewModel.kommunerByFylke.enumerated()), id: \.element.fylke) { index, group in
                    fylkeSection(
                        group: group,
                        sectionTitle: index == 0 ? String(localized: "kommune.section.header") : ""
                    )
                }
            }
        }
    }

    private func fylkeSection(
        group: (fylke: String, kommuner: [KommuneRegion]),
        sectionTitle: String = ""
    ) -> some View {
        let isExpanded = !viewModel.kommuneSearchQuery.isEmpty || expandedFylker.contains(group.fylke)

        return CardSection(sectionTitle) {
            VStack(spacing: 0) {
                TrakkeMenuRow(
                    label: group.fylke,
                    subtitle: nil,
                    action: {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            if expandedFylker.contains(group.fylke) {
                                expandedFylker.remove(group.fylke)
                            } else {
                                expandedFylker.insert(group.fylke)
                            }
                        }
                    },
                    trailing: {
                        Image(systemName: "chevron.down")
                            .font(Font.Trakke.captionSoft.weight(.semibold))
                            .foregroundStyle(Color.Trakke.textSoft)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                )

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
    }

    private func kommuneRow(_ kommune: KommuneRegion) -> some View {
        let isDownloaded = viewModel.isKommuneDownloaded(kommune)
        let sizeText: String? = {
            guard !isDownloaded else { return nil }
            let maxZoom = kommune.optimalMaxZoom()
            let tiles = kommune.estimatedTileCount(minZoom: 8, maxZoom: maxZoom)
            return OfflineMapService.formatBytes(OfflineMapService.estimateSize(tileCount: tiles))
        }()

        return TrakkeMenuRow(
            label: kommune.name,
            accessibilityValue: isDownloaded
                ? String(localized: "kommune.detail.alreadyDownloaded")
                : sizeText,
            trailing: {
                HStack(spacing: .Trakke.sm) {
                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Font.Trakke.captionSoft.weight(.semibold))
                            .foregroundStyle(Color.Trakke.brand)
                            .accessibilityHidden(true)
                    } else if let sizeText {
                        Text(sizeText)
                            .font(Font.Trakke.captionSoft.monospacedDigit())
                            .foregroundStyle(Color.Trakke.textSoft)
                            .accessibilityHidden(true)
                    }
                    TrakkeMenuRowChevron()
                }
            }
        )
    }
}
