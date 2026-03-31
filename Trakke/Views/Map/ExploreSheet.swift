import SwiftUI

struct ExploreSheet: View {
    @Bindable var poiViewModel: POIViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    @AppStorage(AppStorageKeys.overlayHillshading) private var overlayHillshading = false
    @AppStorage(AppStorageKeys.overlayNaturskog) private var overlayNaturskog = false
    @AppStorage(AppStorageKeys.overlayTurrutebasen) private var overlayTurrutebasen = false
    @AppStorage(AppStorageKeys.naturskogLayerType) private var naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    kartlagSection
                    kartinnholdSection

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "explore.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await knowledgeViewModel.loadCatalog()
                knowledgeViewModel.refreshInstalledPacks()
            }
        }
    }

    // MARK: - Kartlag Section

    private var kartlagSection: some View {
        CardSection(String(localized: "overlay.layers")) {
            VStack(spacing: 0) {
                overlayToggle(
                    label: OverlayLayer.hillshading.displayName,
                    isOn: $overlayHillshading
                )
                Divider()
                overlayToggle(
                    label: String(localized: "map.overlay.naturskog"),
                    isOn: $overlayNaturskog
                )
                if overlayNaturskog {
                    naturskogPicker
                }
                Divider()
                overlayToggle(
                    label: OverlayLayer.turrutebasen.displayName,
                    isOn: $overlayTurrutebasen
                )
            }
        }
    }

    // MARK: - Kartinnhold Section

    @ViewBuilder
    private var kartinnholdSection: some View {
        let hasPacks = !knowledgeViewModel.availablePacks.isEmpty || !knowledgeViewModel.installedPacks.isEmpty

        CardSection(String(localized: "explore.kartinnhold")) {
            VStack(spacing: 0) {
                let groups = ContentGroup.allCases.filter { group in
                    POICategory.allCases.contains { $0.contentGroup == group } ||
                    KnowledgeTheme.phase1.contains { $0.contentGroup == group }
                }

                ForEach(Array(groups.enumerated()), id: \.element) { index, group in
                    if index > 0 {
                        Divider()
                    }

                    let pois = POICategory.allCases
                        .filter { $0.contentGroup == group }
                        .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
                    let themes = KnowledgeTheme.phase1
                        .filter { $0.contentGroup == group }
                        .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }

                    ContentGroupSection(
                        group: group,
                        poiCategories: pois,
                        themes: hasPacks ? themes : [],
                        poiViewModel: poiViewModel,
                        knowledgeViewModel: knowledgeViewModel
                    )
                }

                if knowledgeViewModel.isLoadingCatalog && knowledgeViewModel.availablePacks.isEmpty {
                    Divider()
                    ProgressView()
                        .padding(.vertical, .Trakke.md)
                }
            }
        }
    }

    // MARK: - Overlay Toggle

    private func overlayToggle(
        label: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(Font.Trakke.bodyRegular)
        }
        .tint(Color.Trakke.brand)
        .padding(.vertical, .Trakke.xs)
    }

    // MARK: - Naturskog Sub-Picker

    private var naturskogPicker: some View {
        NaturskogSubPickerView(selectedLayerType: $naturskogLayerType)
    }
}

// MARK: - Content Group Section

private struct ContentGroupSection: View {
    let group: ContentGroup
    let poiCategories: [POICategory]
    let themes: [KnowledgeTheme]
    @Bindable var poiViewModel: POIViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: .Trakke.md) {
                    Image(systemName: group.iconName)
                        .foregroundStyle(Color.Trakke.brand)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(group.displayName)
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.text)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(minHeight: .Trakke.touchMin)
                .contentShape(Rectangle())
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(isExpanded
                ? String(localized: "accessibility.tapToCollapse")
                : String(localized: "accessibility.tapToExpand"))

            if isExpanded {
                // POI items (checkmark toggle)
                ForEach(poiCategories) { category in
                    Divider()
                    poiRow(category)
                }

                // Knowledge theme items (toggle + download)
                ForEach(themes) { theme in
                    Divider()
                    ExploreThemeRow(theme: theme, viewModel: knowledgeViewModel)
                }
            }
        }
    }

    private func poiRow(_ category: POICategory) -> some View {
        Button {
            poiViewModel.toggleCategory(category)
        } label: {
            HStack(spacing: .Trakke.md) {
                Image(category.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color(hex: category.color))
                    .frame(width: 28, height: 28)

                Text(category.displayName)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()

                if poiViewModel.enabledCategories.contains(category) {
                    Image(systemName: "checkmark")
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.brand)
                }
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(poiViewModel.enabledCategories.contains(category) ? .isSelected : [])
    }
}

// MARK: - Theme Row with Pack List

private struct ExploreThemeRow: View {
    let theme: KnowledgeTheme
    @Bindable var viewModel: KnowledgeViewModel
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var packs: [KnowledgePack] {
        viewModel.packsForTheme(theme).sorted { $0.countyName < $1.countyName }
    }

    private var hasInstalledPacks: Bool {
        packs.contains { pack in viewModel.installedPacks.contains { $0.id == pack.id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .Trakke.xs) {
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: theme.iconName)
                        .foregroundStyle(Color(hex: theme.color))
                        .frame(width: 24)
                    Text(theme.displayName)
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.text)

                    Spacer()

                    if hasInstalledPacks {
                        Toggle(theme.displayName, isOn: Binding(
                            get: { viewModel.enabledThemes.contains(theme) },
                            set: { _ in viewModel.toggleTheme(theme) }
                        ))
                        .tint(Color.Trakke.brand)
                        .labelsHidden()
                    }

                    Image(systemName: "chevron.right")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(minHeight: .Trakke.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded
                ? String(localized: "accessibility.tapToCollapse")
                : String(localized: "accessibility.tapToExpand"))

            if isExpanded {
                ForEach(packs) { pack in
                    packRow(pack)
                }
            }
        }
        .padding(.vertical, .Trakke.xs)
    }

    @ViewBuilder
    private func packRow(_ pack: KnowledgePack) -> some View {
        let isInstalled = viewModel.installedPacks.contains { $0.id == pack.id }
        let downloading = viewModel.activeDownloads[pack.id]

        HStack {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(pack.countyName)
                    .font(Font.Trakke.caption)
                Text(ByteCountFormatter.string(fromByteCount: pack.fileSize, countStyle: .file))
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }

            Spacer()

            if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.Trakke.green)
            } else if let progress = downloading {
                HStack(spacing: .Trakke.xs) {
                    ProgressView(value: progress.percentage)
                        .frame(width: 60)
                        .tint(Color.Trakke.brand)
                    Button {
                        viewModel.cancelDownload(packId: pack.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .accessibilityLabel(String(localized: "common.cancel"))
                }
            } else {
                Button {
                    viewModel.downloadPack(pack)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Color.Trakke.brand)
                }
                .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                .accessibilityLabel(String(localized: "knowledge.download"))
            }
        }
        .padding(.leading, 28)
    }
}
