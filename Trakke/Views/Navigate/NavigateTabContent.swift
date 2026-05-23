import SwiftUI
import CoreLocation

/// Naviger-fanen — Ruter, Steder, Turer.
/// Bruker isEmbedded-modus av RouteListSheet, WaypointListSheet og
/// ActivityListSheet for å gjenbruke all eksisterende liste-logikk
/// (importer, eksporter, kategorier, kontekstmeny, kart-synlighet) uten
/// dobbel header eller dobbel NavigationStack.
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
        String(localized: "routes.title"),
        String(localized: "waypoints.title"),
        String(localized: "activities.title"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrakkeSheetHeader(title: String(localized: "appTab.navigate"))

                TrakkeUnderlineTabs(
                    titles: subTabs,
                    selectedIndex: $selectedSubTab
                )

                Group {
                    switch selectedSubTab {
                    case 0: routeContent
                    case 1: waypointContent
                    case 2: activityContent
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.Trakke.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Ruter

    private var routeContent: some View {
        RouteListSheet(
            viewModel: routeViewModel,
            onRouteSelected: { route in
                onRouteSelected(route)
            },
            onNewRoute: {
                onNewRoute()
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

    // MARK: - Turer

    private var activityContent: some View {
        ActivityListSheet(
            viewModel: activityViewModel,
            routeViewModel: routeViewModel,
            onActivitySelected: { activity in
                onActivitySelected(activity)
            },
            onStartRecording: {
                onStartRecording()
            },
            onRetrace: { coord in
                onActivityRetrace(coord)
            },
            onFollowAgain: { activity in
                onActivityFollow(activity)
            },
            isEmbedded: true,
            dismissSheet: { dismiss() }
        )
    }
}
