import SwiftUI

/// Konsolidert flate for å starte nedlasting av et offline-kartområde.
/// Én sammenhengende liste i Tråkkes menyvalg-standard: én rad for å tegne
/// eget område på kartet, og kommune-tre under (alfabetisk per fylke).
/// KommuneDetailView pushes via parent NavigationStack når en kommune velges.
struct OfflineSetupSheet: View {
    @Bindable var viewModel: OfflineViewModel
    var onCustom: () -> Void
    /// Viser et nedlastet område på kartet. Nil skjuler handlingen – da er
    /// raden fortsatt en vei til lista, bare uten kart-hopp.
    var onShowOnMap: ((OfflinePackInfo) -> Void)?
    /// Inline-modus: ingen NavigationStack/title/presentationDetents – kalleren
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
                // Lista over nedlastede områder må være fersk før raden over
                // kan si hvor mange og hvor store de er.
                viewModel.loadPacks()
            }
    }

    private var scrollableContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                downloadedSection

                // Tegn eget område på kartet – handling, ikke hierarki.
                VStack(alignment: .leading, spacing: .Trakke.sm) {
                    Text(String(localized: "offline.choice.custom"))
                        .font(Font.Trakke.sectionHeader)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .textCase(.uppercase)
                        .padding(.horizontal, .Trakke.xs)

                    Button {
                        dismiss()
                        onCustom()
                    } label: {
                        Text(String(localized: "offline.selectArea"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.trakkeSecondary)
                }

                // Kommune-tre per fylke
                kommuneSection
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
            .padding(.bottom, .Trakke.xxl)
        }
    }

    /// Veien til å se og forvalte det du allerede har lastet ned. Vises bare
    /// når det finnes noe – en tom rad ville vært støy i en flate som ellers
    /// handler om å laste ned.
    ///
    /// `DownloadManagerSheet` var bygget, dokumentert i brukerveiledningen og
    /// utilgjengelig: ingen kodelinje satte `SheetCoordinator.offlineManager`.
    /// Inngangen forsvant sannsynligvis da MerSheet ble erstattet av faner.
    @ViewBuilder
    private var downloadedSection: some View {
        if !viewModel.packs.isEmpty {
            NavigationLink {
                DownloadManagerSheet(
                    viewModel: viewModel,
                    isEmbedded: true,
                    onShowOnMap: onShowOnMap
                )
            } label: {
                HStack(spacing: .Trakke.sm) {
                    // Ingen ikon: menyrader i Tråkke bærer bare tekst. Et ikon
                    // her ville vært pynt, og appen skal være distraksjonsfri.
                    VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                        Text(String(localized: "offline.manager.title"))
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.text)
                        Text(downloadedSummary)
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
                .padding(.vertical, .Trakke.rowVertical)
                .padding(.horizontal, .Trakke.md)
                .frame(minHeight: .Trakke.touchMin)
                .background(Color.Trakke.surface)
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
            }
            .buttonStyle(.plain)
        }
    }

    private var downloadedSummary: String {
        let bytes = viewModel.packs.reduce(Int64(0)) {
            $0 + Int64($1.progress.completedBytes)
        }
        // Interpolasjonsformen, ikke `String(format:)`: bare den slår opp
        // flertallsvariantene, så det blir «1 område», ikke «1 områder».
        let areas = String(localized: "offline.areaCount \(viewModel.packs.count)")
        return "\(areas) · \(OfflineMapService.formatBytes(bytes))"
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
                // Alle fylker samlet i ett kort – samme mønster som
                // Datakilder + Åpen kildekode i Om-fanen.
                // Fylker er separert med Divider, ikke cardGap.
                CardSection(String(localized: "kommune.section.header")) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.kommunerByFylke.enumerated()), id: \.element.fylke) { index, group in
                            if index > 0 {
                                Divider().padding(.leading, .Trakke.dividerLeading)
                            }
                            fylkeSection(group: group)
                        }
                    }
                }
            }
        }
    }

    private func fylkeSection(
        group: (fylke: String, kommuner: [KommuneRegion])
    ) -> some View {
        let isExpanded = !viewModel.kommuneSearchQuery.isEmpty || expandedFylker.contains(group.fylke)

        return VStack(spacing: 0) {
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
