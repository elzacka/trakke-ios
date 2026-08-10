import SwiftUI
import CoreLocation

/// Naviger-fanen – to under-faner: **Turer og ruter** (sammenslått) og **Steder**.
/// Bruker isEmbedded-modus av TracksListSheet og WaypointListSheet for å
/// gjenbruke all eksisterende liste-logikk (importer, eksporter, kategorier,
/// kontekstmeny, kart-synlighet) uten dobbel header eller dobbel
/// NavigationStack.
struct NavigateTabContent: View {
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var waypointViewModel: WaypointViewModel
    @Bindable var activityViewModel: ActivityViewModel
    var onRouteSelected: (Route) -> Void
    var onNewRoute: () -> Void
    var onWaypointEdit: (Waypoint) -> Void
    var onWaypointNavigate: (CLLocationCoordinate2D) -> Void
    var onActivitySelected: (Activity) -> Void
    var onActivityRetrace: (CLLocationCoordinate2D) -> Void
    var onActivityFollow: (Activity) -> Void
    var onStartRecording: () -> Void
    @State private var selectedSubTab: Int = 0
    @Environment(\.dismiss) private var dismiss

    private let subTabs = [
        String(localized: "tracks.title"),
        String(localized: "waypoints.title"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrakkeSheetHeader()

                TrakkeUnderlineTabs(
                    titles: subTabs,
                    selectedIndex: $selectedSubTab
                )

                Group {
                    switch selectedSubTab {
                    case 0: tracksContent
                    case 1: waypointContent
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.Trakke.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Turer og ruter

    private var tracksContent: some View {
        TracksListSheet(
            routeViewModel: routeViewModel,
            activityViewModel: activityViewModel,
            onRouteSelected: { route in
                onRouteSelected(route)
            },
            onActivityRetrace: { coord in
                onActivityRetrace(coord)
            },
            onActivityFollow: { activity in
                onActivityFollow(activity)
            },
            onNewRoute: {
                onNewRoute()
            },
            onStartRecording: {
                onStartRecording()
            },
            isEmbedded: true,
            dismissSheet: { dismiss() }
        )
    }

    // MARK: - Steder

    private var waypointContent: some View {
        WaypointListSheet(
            viewModel: waypointViewModel,
            onWaypointEdit: { waypoint in
                onWaypointEdit(waypoint)
            },
            onWaypointNavigate: { coordinate in
                onWaypointNavigate(coordinate)
            },
            isEmbedded: true,
            dismissSheet: { dismiss() }
        )
    }
}
