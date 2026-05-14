import SwiftUI
import CoreLocation

// MARK: - Tab Identitet

/// Hvilken fane som er aktiv i Bibliotek.
enum BibliotekTab: Hashable, CaseIterable, Identifiable {
    case myStuff
    case explore
    case more

    var id: Self { self }

    var localizedTitle: String {
        switch self {
        case .myStuff: return String(localized: "mystuff.title")
        case .explore: return String(localized: "explore.title")
        case .more: return String(localized: "more.title")
        }
    }
}

// MARK: - Navigasjonsmål

private enum BibliotekMyStuffDestination: Hashable {
    case routes
    case waypoints
    case activities
    case offlinePacks
}

private enum BibliotekMoreDestination: Hashable {
    case knowledge
    case info
    case preferences
}

// MARK: - BibliotekSheet

/// Konsolidert flate som erstatter MineGreier / Explore / More.
/// Tre faner: Mine greier, Utforsk, Mer.
struct BibliotekSheet: View {
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var waypointViewModel: WaypointViewModel
    @Bindable var activityViewModel: ActivityViewModel
    @Bindable var poiViewModel: POIViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    @Bindable var mapViewModel: MapViewModel
    @Bindable var offlineViewModel: OfflineViewModel

    // MARK: Callbacks

    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    var onWaypointSelected: ((Waypoint) -> Void)?
    var onWaypointEdit: ((Waypoint) -> Void)?
    var onWaypointNavigate: ((CLLocationCoordinate2D) -> Void)?
    var onActivitySelected: ((Activity) -> Void)?
    var onActivityRetrace: ((CLLocationCoordinate2D) -> Void)?
    var onActivityFollow: ((Activity) -> Void)?
    var onStartRecording: (() -> Void)?
    var onMeasurementTapped: (() -> Void)?
    var onOfflineTapped: (() -> Void)?
    var onDeleteAllData: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: BibliotekTab
    @State private var navigationPath = NavigationPath()

    @AppStorage(AppStorageKeys.overlayHillshading) private var overlayHillshading = false
    @AppStorage(AppStorageKeys.overlayNaturskog) private var overlayNaturskog = false
    @AppStorage(AppStorageKeys.overlayTurrutebasen) private var overlayTurrutebasen = false
    @AppStorage(AppStorageKeys.naturskogLayerType) private var naturskogLayerType = OverlayLayer.naturskogSannsynlighet.rawValue

    init(
        initialTab: BibliotekTab,
        routeViewModel: RouteViewModel,
        waypointViewModel: WaypointViewModel,
        activityViewModel: ActivityViewModel,
        poiViewModel: POIViewModel,
        knowledgeViewModel: KnowledgeViewModel,
        mapViewModel: MapViewModel,
        offlineViewModel: OfflineViewModel,
        onRouteSelected: ((Route) -> Void)? = nil,
        onNewRoute: (() -> Void)? = nil,
        onWaypointSelected: ((Waypoint) -> Void)? = nil,
        onWaypointEdit: ((Waypoint) -> Void)? = nil,
        onWaypointNavigate: ((CLLocationCoordinate2D) -> Void)? = nil,
        onActivitySelected: ((Activity) -> Void)? = nil,
        onActivityRetrace: ((CLLocationCoordinate2D) -> Void)? = nil,
        onActivityFollow: ((Activity) -> Void)? = nil,
        onStartRecording: (() -> Void)? = nil,
        onMeasurementTapped: (() -> Void)? = nil,
        onOfflineTapped: (() -> Void)? = nil,
        onDeleteAllData: (() -> Void)? = nil
    ) {
        self._selectedTab = State(initialValue: initialTab)
        self.routeViewModel = routeViewModel
        self.waypointViewModel = waypointViewModel
        self.activityViewModel = activityViewModel
        self.poiViewModel = poiViewModel
        self.knowledgeViewModel = knowledgeViewModel
        self.mapViewModel = mapViewModel
        self.offlineViewModel = offlineViewModel
        self.onRouteSelected = onRouteSelected
        self.onNewRoute = onNewRoute
        self.onWaypointSelected = onWaypointSelected
        self.onWaypointEdit = onWaypointEdit
        self.onWaypointNavigate = onWaypointNavigate
        self.onActivitySelected = onActivitySelected
        self.onActivityRetrace = onActivityRetrace
        self.onActivityFollow = onActivityFollow
        self.onStartRecording = onStartRecording
        self.onMeasurementTapped = onMeasurementTapped
        self.onOfflineTapped = onOfflineTapped
        self.onDeleteAllData = onDeleteAllData
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(BibliotekTab.allCases) { tab in
                        Text(tab.localizedTitle).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.vertical, .Trakke.sm)

                Group {
                    switch selectedTab {
                    case .myStuff: myStuffContent
                    case .explore: exploreContent
                    case .more: moreContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(selectedTab.localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BibliotekMyStuffDestination.self) { destination in
                myStuffDestinationView(for: destination)
            }
            .navigationDestination(for: BibliotekMoreDestination.self) { destination in
                moreDestinationView(for: destination)
            }
            .navigationDestination(for: KnowledgeDestination.self) { destination in
                switch destination {
                case .category(let category):
                    KnowledgeCategoryView(category: category, viewModel: knowledgeViewModel)
                case .article(let article):
                    ArticleDetailView(article: article)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onChange(of: selectedTab) { _, _ in
            navigationPath = NavigationPath()
        }
        .task {
            await knowledgeViewModel.loadCatalog()
            knowledgeViewModel.refreshInstalledPacks()
        }
    }

    // MARK: - Tab: Mine greier

    private var myStuffContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection {
                    bibliotekMenuLink(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        label: String(localized: "routes.title"),
                        count: routeViewModel.routes.count,
                        destination: BibliotekMyStuffDestination.routes
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    bibliotekMenuLink(
                        icon: "mappin",
                        label: String(localized: "mystuff.places"),
                        count: waypointViewModel.waypoints.count,
                        destination: BibliotekMyStuffDestination.waypoints
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    bibliotekMenuLink(
                        icon: "figure.hiking",
                        label: String(localized: "activity.title"),
                        count: activityViewModel.activities.count,
                        destination: BibliotekMyStuffDestination.activities
                    )
                    // Offline-kart dukker bare opp her når brukeren faktisk har
                    // lastet ned noe. Tomt = ikke synlig (Rams: ikke vis det som
                    // ikke er der). Nye nedlastinger initieres fra «Mer»-fanen.
                    if !offlineViewModel.packs.isEmpty {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                        bibliotekMenuLink(
                            icon: "arrow.down.circle",
                            label: String(localized: "offline.title"),
                            count: offlineViewModel.packs.count,
                            destination: BibliotekMyStuffDestination.offlinePacks
                        )
                    }
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
    }

    @ViewBuilder
    private func myStuffDestinationView(for destination: BibliotekMyStuffDestination) -> some View {
        switch destination {
        case .routes:
            RouteListSheet(
                viewModel: routeViewModel,
                onRouteSelected: { route in
                    onRouteSelected?(route)
                    dismiss()
                },
                onNewRoute: {
                    onNewRoute?()
                    dismiss()
                },
                isEmbedded: true,
                dismissSheet: { dismiss() }
            )
        case .waypoints:
            WaypointListSheet(
                viewModel: waypointViewModel,
                onWaypointSelected: { wp in
                    onWaypointSelected?(wp)
                },
                onWaypointEdit: { wp in
                    onWaypointEdit?(wp)
                    dismiss()
                },
                onWaypointNavigate: { coord in
                    onWaypointNavigate?(coord)
                    dismiss()
                },
                isEmbedded: true,
                dismissSheet: { dismiss() }
            )
        case .activities:
            ActivityListSheet(
                viewModel: activityViewModel,
                routeViewModel: routeViewModel,
                onActivitySelected: { _ in },
                onStartRecording: {
                    onStartRecording?()
                    dismiss()
                },
                onRetrace: { coord in
                    onActivityRetrace?(coord)
                    dismiss()
                },
                onFollowAgain: { activity in
                    onActivityFollow?(activity)
                    dismiss()
                },
                isEmbedded: true,
                dismissSheet: { dismiss() }
            )
        case .offlinePacks:
            DownloadManagerSheet(
                viewModel: offlineViewModel,
                onNewDownload: {
                    onOfflineTapped?()
                },
                isEmbedded: true,
                dismissSheet: { dismiss() }
            )
        }
    }

    // MARK: - Tab: Utforsk

    private var exploreContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                kartlagSection
                kartinnholdSection
                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
    }

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
                    NaturskogSubPickerView(selectedLayerType: $naturskogLayerType)
                }
                Divider()
                overlayToggle(
                    label: OverlayLayer.turrutebasen.displayName,
                    isOn: $overlayTurrutebasen
                )
            }
        }
    }

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

                    BibliotekContentGroupSection(
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

    private func overlayToggle(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label).font(Font.Trakke.bodyRegular)
        }
        .tint(Color.Trakke.brand)
        .padding(.vertical, .Trakke.xs)
    }

    // MARK: - Tab: Mer

    private var moreContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection {
                    bibliotekActionButton(icon: "ruler", label: String(localized: "measurement.title")) {
                        dismiss()
                        onMeasurementTapped?()
                    }
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    bibliotekActionButton(icon: "arrow.down.circle", label: String(localized: "offline.title")) {
                        dismiss()
                        onOfflineTapped?()
                    }
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    bibliotekMenuLink(
                        icon: "book.closed",
                        label: String(localized: "knowledge.title"),
                        count: 0,
                        destination: BibliotekMoreDestination.knowledge
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    bibliotekMenuLink(
                        icon: "info.circle",
                        label: String(localized: "info.title"),
                        count: 0,
                        destination: BibliotekMoreDestination.info
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    bibliotekMenuLink(
                        icon: "gearshape",
                        label: String(localized: "settings.title"),
                        count: 0,
                        destination: BibliotekMoreDestination.preferences
                    )
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
    }

    @ViewBuilder
    private func moreDestinationView(for destination: BibliotekMoreDestination) -> some View {
        switch destination {
        case .knowledge:
            KnowledgeSheet(viewModel: knowledgeViewModel, isEmbedded: true)
        case .info:
            InfoSheet(isEmbedded: true)
        case .preferences:
            PreferencesSheet(
                mapViewModel: mapViewModel,
                knowledgeViewModel: knowledgeViewModel,
                onDeleteAllData: onDeleteAllData,
                isEmbedded: true
            )
        }
    }

    // MARK: - Felles menyrad-bygging

    private func bibliotekMenuLink<Destination: Hashable>(
        icon: String,
        label: String,
        count: Int,
        destination: Destination
    ) -> some View {
        Button {
            navigationPath.append(destination)
        } label: {
            HStack(spacing: .Trakke.md) {
                Image(systemName: icon)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }

                Image(systemName: "chevron.right")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "\(label), \(count)" : label)
    }

    private func bibliotekActionButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: .Trakke.md) {
                Image(systemName: icon)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Content Group Section (POI + Knowledge)

private struct BibliotekContentGroupSection: View {
    let group: ContentGroup
    let poiCategories: [POICategory]
    let themes: [KnowledgeTheme]
    @Bindable var poiViewModel: POIViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
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
                ForEach(poiCategories) { category in
                    Divider()
                    poiRow(category)
                }
                ForEach(themes) { theme in
                    Divider()
                    BibliotekThemeRow(theme: theme, viewModel: knowledgeViewModel)
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
                    .accessibilityHidden(true)

                Text(category.displayName)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()

                if poiViewModel.enabledCategories.contains(category) {
                    Image(systemName: "checkmark")
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.brand)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(category.displayName)
        .accessibilityValue(poiViewModel.enabledCategories.contains(category)
            ? String(localized: "accessibility.enabled")
            : String(localized: "accessibility.disabled"))
        .accessibilityAddTraits(poiViewModel.enabledCategories.contains(category) ? .isSelected : [])
    }
}

// MARK: - Theme Row with Pack List

private struct BibliotekThemeRow: View {
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
