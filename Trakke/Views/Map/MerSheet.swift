import SwiftUI
import CoreLocation

// MARK: - Navigasjonsmål

private enum MerDestination: Hashable {
    case routes
    case waypoints
    case activities
    case offlinePacks
    case knowledge
    case settings
    case info
}

// MARK: - MerSheet
//
// Én flat skroll-flate. Ingen tabs, ingen accordions, ingen pynt-ikoner.
// Settings.app-mønster: avsnittsoverskrifter i kapitaler + rene rader.
// Pil-rader pusher til detalj, handlingsrader uten pil utfører handling.

struct MerSheet: View {
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var waypointViewModel: WaypointViewModel
    @Bindable var activityViewModel: ActivityViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    @Bindable var mapViewModel: MapViewModel
    @Bindable var offlineViewModel: OfflineViewModel

    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    var onWaypointEdit: ((Waypoint) -> Void)?
    var onWaypointNavigate: ((CLLocationCoordinate2D) -> Void)?
    var onActivityRetrace: ((CLLocationCoordinate2D) -> Void)?
    var onActivityFollow: ((Activity) -> Void)?
    var onStartRecording: (() -> Void)?
    var onMeasurementTapped: (() -> Void)?
    var onOfflineTapped: (() -> Void)?
    var onDeleteAllData: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    mineTingSection
                    verktoySection
                    kunnskapOgOmSection
                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.lg)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MerDestination.self) { destination in
                destinationView(for: destination)
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
        .task {
            await knowledgeViewModel.loadCatalog()
            knowledgeViewModel.refreshInstalledPacks()
        }
    }

    // MARK: - Seksjon: MINE TING

    private var mineTingSection: some View {
        CardSection(String(localized: "mystuff.title")) {
            VStack(spacing: 0) {
                pushRow(label: String(localized: "routes.title"),
                        count: routeViewModel.routes.count,
                        destination: .routes)
                Divider().padding(.leading, .Trakke.dividerLeading)
                pushRow(label: String(localized: "mystuff.places"),
                        count: waypointViewModel.waypoints.count,
                        destination: .waypoints)
                Divider().padding(.leading, .Trakke.dividerLeading)
                pushRow(label: String(localized: "activity.title"),
                        count: activityViewModel.activities.count,
                        destination: .activities)
                if !offlineViewModel.packs.isEmpty {
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    pushRow(label: String(localized: "offline.title"),
                            count: offlineViewModel.packs.count,
                            destination: .offlinePacks)
                }
            }
        }
    }

    // MARK: - Seksjon: VERKTØY

    private var verktoySection: some View {
        CardSection(String(localized: "explore.title")) {
            VStack(spacing: 0) {
                actionRow(label: String(localized: "measurement.title")) {
                    dismiss()
                    onMeasurementTapped?()
                }
                Divider().padding(.leading, .Trakke.dividerLeading)
                actionRow(label: String(localized: "offline.title")) {
                    dismiss()
                    onOfflineTapped?()
                }
            }
        }
    }

    // MARK: - Seksjon: KUNNSKAP OG OM

    private var kunnskapOgOmSection: some View {
        CardSection(String(localized: "more.title")) {
            VStack(spacing: 0) {
                pushRow(label: String(localized: "knowledge.title"),
                        count: nil,
                        destination: .knowledge)
                Divider().padding(.leading, .Trakke.dividerLeading)
                pushRow(label: String(localized: "settings.title"),
                        count: nil,
                        destination: .settings)
                Divider().padding(.leading, .Trakke.dividerLeading)
                pushRow(label: String(localized: "info.title"),
                        count: nil,
                        destination: .info)
            }
        }
    }

    // MARK: - Destinasjonsrendring

    @ViewBuilder
    private func destinationView(for destination: MerDestination) -> some View {
        switch destination {
        case .routes:
            RouteListSheet(
                viewModel: routeViewModel,
                onRouteSelected: { route in
                    dismiss()
                    onRouteSelected?(route)
                },
                onNewRoute: {
                    dismiss()
                    onNewRoute?()
                },
                isEmbedded: true,
                dismissSheet: { dismiss() }
            )
        case .waypoints:
            WaypointListSheet(
                viewModel: waypointViewModel,
                onWaypointSelected: { _ in },
                onWaypointEdit: { wp in
                    // Ikke kall dismiss() etter dette — onWaypointEdit endrer
                    // sheets.active = .waypointEdit, og SwiftUIs .sheet(item:)
                    // bytter automatisk fra .merSheet til .waypointEdit. Et
                    // ekstra dismiss-kall ville sette sheets.active = nil og
                    // kansellere den nye sheeten.
                    onWaypointEdit?(wp)
                },
                onWaypointNavigate: { coord in
                    onWaypointNavigate?(coord)
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
                    dismiss()
                    onStartRecording?()
                },
                onRetrace: { coord in
                    // Samme mønster: onRetrace setter sheets.active =
                    // .navigationStart — SwiftUI håndterer overgangen.
                    onActivityRetrace?(coord)
                },
                onFollowAgain: { activity in
                    dismiss()
                    onActivityFollow?(activity)
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
        case .knowledge:
            KnowledgeSheet(viewModel: knowledgeViewModel, isEmbedded: true)
        case .settings:
            PreferencesSheet(
                mapViewModel: mapViewModel,
                knowledgeViewModel: knowledgeViewModel,
                onDeleteAllData: onDeleteAllData,
                isEmbedded: true
            )
        case .info:
            InfoSheet(isEmbedded: true)
        }
    }

    // MARK: - Radkomponenter

    /// Rad som pusher til en destinasjon. Tekst + valgfri count + chevron.
    private func pushRow(label: String, count: Int?, destination: MerDestination) -> some View {
        Button {
            navigationPath.append(destination)
        } label: {
            HStack(spacing: .Trakke.md) {
                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)
                Spacer()
                if let count, count > 0 {
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
        .accessibilityLabel(count.map { $0 > 0 ? "\(label), \($0)" : label } ?? label)
    }

    /// Rad som utfører en handling og lukker sheeten. Bare tekst, ingen pil.
    private func actionRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)
                Spacer()
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
