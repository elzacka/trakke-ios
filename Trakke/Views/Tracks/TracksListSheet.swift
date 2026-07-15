import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

/// Sammenslaatt liste over **ruter** (planlagte linjer, kan tegnes/importeres)
/// og **turer** (GPS-opptak, kan logges/importeres). Erstatter de tidligere
/// separate `RouteListSheet` og `ActivityListSheet`.
///
/// Begge typer deler kategori-rom – en kategori med navnet «Vinter» kan
/// inneholde både ruter og turer, og vises som én gruppe.
///
/// Action-bar har fire ikoner: `+` (handlings-valg: Logg tur / Tegn rute),
/// import (auto-detekterer rute vs tur fra fil), eksport (handlings-valg
/// per type), slett alle (handlings-valg per type).
struct TracksListSheet: View {
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var activityViewModel: ActivityViewModel

    var onRouteSelected: ((Route) -> Void)?
    var onActivityRetrace: ((CLLocationCoordinate2D) -> Void)?
    var onActivityFollow: ((Activity) -> Void)?
    var onNewRoute: () -> Void
    var onStartRecording: () -> Void

    var isEmbedded = false
    var dismissSheet: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showFileImporter = false
    @State private var showCreateOptions = false
    @State private var showExportOptions = false
    @State private var showDeleteOptions = false
    @State private var editingRoute: Route?
    @State private var editingActivity: Activity?
    @State private var shareURL: ShareableURL?
    @State private var importMessage: String?
    @State private var expandedCategories: Set<String> = []

    private func dismissFully() {
        if let dismissSheet { dismissSheet() } else { dismiss() }
    }

    // MARK: - Track Item

    /// Enum-wrapper som lar `ForEach` rendre rute-rader og tur-rader om
    /// hverandre i samme liste. Bare innebygd der det trengs – handlinger
    /// kaller ViewModels direkte på riktig type via mønster-matching.
    enum TrackItem: Identifiable, Hashable {
        case route(Route)
        case activity(Activity)

        var id: String {
            switch self {
            case .route(let r): "r:\(r.id)"
            case .activity(let a): "a:\(a.id)"
            }
        }

        /// Brukes til sortering i sammenslått liste – nyeste øverst.
        var sortDate: Date {
            switch self {
            case .route(let r): r.createdAt
            case .activity(let a): a.startedAt
            }
        }
    }

    // MARK: - Body

    var body: some View {
        if isEmbedded {
            content
        } else {
            NavigationStack {
                content
            }
        }
    }

    private var content: some View {
        list
            .background(Color.Trakke.background)
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "tracks.title"))
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.gpx, .geoJSON],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    Task { await handleImport(url: url) }
                }
            }
            .overlay(alignment: .bottom) {
                if importMessage != nil {
                    importBanner
                }
            }
            .sheet(item: $editingRoute) { route in
                editRouteSheet(route)
            }
            .sheet(item: $editingActivity) { activity in
                editActivitySheet(activity)
            }
            .sheet(item: $shareURL) { item in
                ShareSheet(activityItems: [item.url])
            }
            .navigationDestination(for: Route.self) { route in
                RouteDetailSheet(
                    viewModel: routeViewModel,
                    route: route,
                    onNavigate: { route in
                        onRouteSelected?(route)
                        dismissFully()
                    },
                    isEmbedded: true
                )
            }
            .navigationDestination(for: Activity.self) { activity in
                ActivityDetailSheet(
                    viewModel: activityViewModel,
                    activity: activity,
                    onRetrace: { coordinate in
                        onActivityRetrace?(coordinate)
                        dismissFully()
                    },
                    onFollowAgain: { activity in
                        onActivityFollow?(activity)
                        dismissFully()
                    },
                    isEmbedded: true
                )
            }
            // Tittel utelatt – knappene («Logg tur» / «Tegn rute» /
            // «Eksporter alle ruter» osv.) er selvforklarende, og en
            // tittel som «Logg tur eller tegn rute» repeterer bare. Følger
            // mønsteret fra de øvrige action-sheet-dialogene (long-press,
            // navigasjon-more).
            .trakkeDialog(
                isPresented: $showCreateOptions,
                buttons: createDialogButtons
            )
            .trakkeDialog(
                isPresented: $showExportOptions,
                buttons: exportDialogButtons
            )
            .trakkeDialog(
                isPresented: $showDeleteOptions,
                title: String(localized: "tracks.deleteAll.confirmTitle"),
                message: String(localized: "tracks.deleteAll.confirmMessage"),
                primary: .destructive(String(localized: "common.yes")) {
                    routeViewModel.deleteAllRoutes()
                    activityViewModel.deleteAllActivities()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
            .onAppear {
                activityViewModel.loadActivities()
            }
    }

    // MARK: - Dialog Buttons
    //
    // Ekstrahert som computed properties slik at hver `.trakkeDialog(...)`-
    // kall i `content` blir enklere for SwiftUI-type-checkeren og knappe-
    // logikken kan leses uavhengig av modifier-kjeden.

    private var createDialogButtons: [TrakkeDialogButton] {
        [
            .primary(String(localized: "activity.log")) {
                dismissFully()
                onStartRecording()
            },
            .primary(String(localized: "routes.draw")) {
                onNewRoute()
                dismissFully()
            },
            .cancel()
        ]
    }

    private var exportDialogButtons: [TrakkeDialogButton] {
        var buttons: [TrakkeDialogButton] = []
        if !routeViewModel.routes.isEmpty {
            buttons.append(.primary(String(localized: "tracks.export.routes")) {
                if let url = routeViewModel.exportAllGPX() {
                    shareURL = ShareableURL(url: url)
                }
            })
        }
        if !activityViewModel.activities.isEmpty {
            buttons.append(.primary(String(localized: "tracks.export.activities")) {
                if let url = activityViewModel.exportAllGPX() {
                    shareURL = ShareableURL(url: url)
                }
            })
        }
        buttons.append(.cancel())
        return buttons
    }

    // MARK: - Helpers

    /// Union av kategorier fra begge view-modeller, alfabetisk sortert.
    private var allCategories: [String] {
        Array(Set(routeViewModel.categories + activityViewModel.categories)).sorted()
    }

    private func items(forCategory category: String?) -> [TrackItem] {
        let routes: [Route]
        let activities: [Activity]
        if let category {
            routes = routeViewModel.routes(for: category)
            activities = activityViewModel.activities(for: category)
        } else {
            routes = routeViewModel.uncategorizedRoutes
            activities = activityViewModel.uncategorizedActivities
        }
        let items = routes.map(TrackItem.route) + activities.map(TrackItem.activity)
        return items.sorted { $0.sortDate > $1.sortDate }
    }

    private var hasUncategorized: Bool {
        !routeViewModel.uncategorizedRoutes.isEmpty
            || !activityViewModel.uncategorizedActivities.isEmpty
    }

    private var isEmpty: Bool {
        routeViewModel.routes.isEmpty && activityViewModel.activities.isEmpty
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                actionBar

                if isEmpty {
                    EmptyStateView(
                        title: String(localized: "tracks.empty.title"),
                        subtitle: String(localized: "tracks.empty.subtitle"),
                        alignment: .leading
                    )
                    .padding(.top, .Trakke.xxl)
                } else {
                    ForEach(allCategories, id: \.self) { category in
                        trackGroup(title: category, category: category, items: items(forCategory: category))
                    }

                    if hasUncategorized {
                        trackGroup(
                            title: allCategories.isEmpty
                                ? String(localized: "tracks.saved")
                                : String(localized: "tracks.uncategorized"),
                            category: nil,
                            items: items(forCategory: nil)
                        )
                    }
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color.Trakke.background)
    }

    // MARK: - Group

    private func trackGroup(title: String, category: String?, items: [TrackItem]) -> some View {
        VStack(spacing: 0) {
            categoryHeader(title: title, count: items.count)

            if expandedCategories.contains(title) {
                Divider().padding(.leading, .Trakke.dividerLeading)

                ForEach(items) { item in
                    if items.first?.id != item.id {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    switch item {
                    case .route(let route): routeRow(route)
                    case .activity(let activity): activityRow(activity)
                    }
                }
            }
        }
        .padding(.horizontal, .Trakke.cardPadH)
        .background(Color.Trakke.surface)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
    }

    // MARK: - Route Row

    private func routeRow(_ route: Route) -> some View {
        HStack(spacing: 0) {
            NavigationLink(value: route) {
                routeRowContent(route)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    routeViewModel.showOnly(route)
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: String(localized: "list.showOnlyThis.announce \(route.name)")
                    )
                } label: {
                    Label(
                        String(localized: "routes.showOnlyThis"),
                        systemImage: "eye.circle"
                    )
                }

                Button {
                    editingRoute = route
                } label: {
                    Label(String(localized: "common.edit"), systemImage: "pencil")
                }

                Button(role: .destructive) {
                    routeViewModel.deleteRoute(route)
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            }

            VisibilityToggleButton(
                isVisible: route.isVisible,
                accessibilityLabel: route.isVisible
                    ? String(localized: "routes.hideFromMap")
                    : String(localized: "routes.showOnMap")
            ) {
                routeViewModel.toggleVisibility(route)
            }
        }
    }

    private func routeRowContent(_ route: Route) -> some View {
        HStack(spacing: .Trakke.md) {
            // Skjult tilstand dempes kun på farge-prikken, ikke på teksten –
            // teksten må holde full kontrast (WCAG 1.4.3).
            Circle()
                .fill(Color(hex: route.color ?? "#E07000"))
                .frame(width: 12, height: 12)
                .opacity(route.isVisible ? 1 : 0.45)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(route.name)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)

                Text(routeViewModel.formattedDistance(route.distance))
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textSoft)
            }

            Spacer()

            if !route.isVisible {
                Image(systemName: "eye.slash")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: .Trakke.touchMin)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(routeAccessibilityLabel(route))
    }

    private func routeAccessibilityLabel(_ route: Route) -> String {
        var parts = [route.name, routeViewModel.formattedDistance(route.distance)]
        if let gain = route.elevationGain, gain > 0 {
            parts.append("+\(Int(gain)) m")
        }
        if !route.isVisible {
            parts.append(String(localized: "routes.hiddenFromMap"))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Activity Row

    private func activityRow(_ activity: Activity) -> some View {
        HStack(spacing: 0) {
            NavigationLink(value: activity) {
                activityRowContent(activity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    editingActivity = activity
                } label: {
                    Label(String(localized: "common.edit"), systemImage: "pencil")
                }

                Button {
                    activityViewModel.convertToRoute(activity, using: routeViewModel)
                } label: {
                    Label(
                        String(localized: "activity.convertToRoute"),
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                }

                Button(role: .destructive) {
                    activityViewModel.deleteActivity(activity)
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            }

            VisibilityToggleButton(
                isVisible: activity.isVisible,
                accessibilityLabel: activity.isVisible
                    ? String(localized: "activity.hideFromMap")
                    : String(localized: "activity.showOnMap")
            ) {
                activityViewModel.toggleVisibility(activity)
            }
        }
    }

    private func activityRowContent(_ activity: Activity) -> some View {
        // Konsistent visuell prefiks: brand-farget prikk (samme størrelse
        // som rute-prikken) slik at rad-strukturen er den samme. Dato til
        // høyre er det som visuelt skiller en tur fra en rute.
        HStack(spacing: .Trakke.md) {
            // Skjult tilstand dempes kun på farge-prikken, ikke på teksten –
            // teksten må holde full kontrast (WCAG 1.4.3).
            Circle()
                .fill(Color.Trakke.brand)
                .frame(width: 12, height: 12)
                .opacity(activity.isVisible ? 1 : 0.45)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                HStack {
                    Text(activity.name)
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.text)
                    Spacer()
                    Text(activity.startedAt, style: .date)
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textSoft)
                }

                Text(ActivityViewModel.formatDistance(activity.distance))
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textSoft)
            }

            if !activity.isVisible {
                Image(systemName: "eye.slash")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: .Trakke.touchMin)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(activityAccessibilityLabel(activity))
    }

    private func activityAccessibilityLabel(_ activity: Activity) -> String {
        let parts = [
            activity.name,
            ActivityViewModel.formatDistance(activity.distance),
            ActivityViewModel.formatDuration(activity.duration),
            "+\(Int(activity.elevationGain)) m"
        ]
        return parts.joined(separator: ", ")
    }

    // MARK: - Category Header

    /// Kategori-header speiler ExpandableSection-stilen (Brukerveiledning,
    /// Personvernerklæring osv.): plain tittel-tekst, chevron-down til
    /// høyre som roterer ved ekspandering, antall-tekst etter tittel.
    /// Per-kategori-synlighet-bryteren er fjernet – brukerne kan toggle
    /// per rad via VisibilityToggleButton som er like tilgjengelig.
    @ViewBuilder
    private func categoryHeader(title: String, count: Int) -> some View {
        let isExpanded = expandedCategories.contains(title)
        Button {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedCategories.remove(title)
                } else {
                    expandedCategories.insert(title)
                }
            }
        } label: {
            HStack(spacing: .Trakke.md) {
                Text(title)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Text("(\(count))")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textSoft)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.textSoft)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, 12)
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint(isExpanded
            ? String(localized: "accessibility.tapToCollapse")
            : String(localized: "accessibility.tapToExpand"))
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: .Trakke.sm) {
            Spacer()

            TrakkeIconButton(
                systemImage: "plus",
                accessibilityLabel: String(localized: "tracks.create.title"),
                action: { showCreateOptions = true }
            )

            TrakkeIconButton(
                systemImage: "square.and.arrow.up",
                isLoading: routeViewModel.isImporting || activityViewModel.isImporting,
                accessibilityLabel: (routeViewModel.isImporting || activityViewModel.isImporting)
                    ? String(localized: "import.inProgress")
                    : String(localized: "import.file"),
                action: { showFileImporter = true }
            )

            TrakkeIconButton(
                systemImage: "square.and.arrow.down",
                isEnabled: !isEmpty,
                accessibilityLabel: String(localized: "import.exportAll"),
                action: { showExportOptions = true }
            )

            TrakkeIconButton(
                systemImage: "trash",
                role: .destructive,
                isEnabled: !isEmpty,
                accessibilityLabel: String(localized: "tracks.deleteAll.title"),
                action: { showDeleteOptions = true }
            )
        }
    }

    // MARK: - File Import

    /// Auto-detekt fil-type. GPX: prøv tur først (krever timestamps i
    /// trackpunkter), fall tilbake til rute. GeoJSON: samme logikk via
    /// `insertImported` på begge view-modeller. Speiler logikken i
    /// `ContentView+FileImport.handleOpenedFile`.
    private func handleImport(url: URL) async {
        let activityCount: Int
        let routeCount: Int

        switch url.pathExtension.lowercased() {
        case "geojson", "json":
            do {
                let result = try GeoJSONImportService.parse(from: url)
                let filename = url.importedItemName
                let aCount = activityViewModel.insertImported(result.activities, filename: filename)
                let rCount = aCount == 0
                    ? routeViewModel.insertImported(result.routes, filename: filename)
                    : 0
                activityCount = aCount
                routeCount = rCount
            } catch {
                importMessage = String(localized: "routes.importError")
                return
            }
        case "gpx":
            let aCount = activityViewModel.importFile(from: url)
            let rCount = aCount > 0 ? 0 : routeViewModel.importFile(from: url)
            activityCount = aCount
            routeCount = rCount
        default:
            importMessage = String(localized: "routes.importError")
            return
        }

        if activityCount > 0 {
            importMessage = String(localized: "tracks.import.activities \(activityCount)")
        } else if routeCount > 0 {
            importMessage = String(localized: "tracks.import.routes \(routeCount)")
        } else {
            importMessage = String(localized: "tracks.import.nothing")
        }
    }

    // MARK: - Edit Sheets

    private func editRouteSheet(_ route: Route) -> some View {
        EditNameCategorySheet(
            title: String(localized: "common.edit"),
            initialName: route.name,
            initialCategory: route.category ?? "",
            categorySuggestions: routeViewModel.categories,
            namePlaceholder: String(localized: "routes.namePlaceholder")
        ) { newName, newCategory in
            routeViewModel.edit(route, name: newName, category: newCategory)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func editActivitySheet(_ activity: Activity) -> some View {
        EditNameCategorySheet(
            title: String(localized: "common.edit"),
            initialName: activity.name,
            initialCategory: activity.category ?? "",
            categorySuggestions: activityViewModel.categories,
            namePlaceholder: String(localized: "activity.save.namePlaceholder")
        ) { newName, newCategory in
            activityViewModel.edit(activity, name: newName, category: newCategory)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Import Banner

    private var importBanner: some View {
        Text(importMessage ?? "")
            .font(Font.Trakke.caption)
            .foregroundStyle(Color.Trakke.textInverse)
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(Color.Trakke.brand)
            .clipShape(Capsule())
            .padding(.bottom, .Trakke.lg)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(reduceMotion ? nil : .default) {
                    importMessage = nil
                }
            }
    }
}
