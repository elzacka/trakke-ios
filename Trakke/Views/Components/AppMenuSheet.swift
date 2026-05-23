import SwiftUI
import CoreLocation

/// Container som komponerer current tab-content + flytende BottomNavBar.
/// Brukes som sheet-innhold når brukeren åpner appmenyen via FAB.
/// BottomNavBar ligger ALLTID nederst i sheet-en, så swipe-ned skjuler
/// både tab-innhold og navigasjon samtidig.
struct AppMenuSheet: View {
    @Binding var selectedTab: AppTab
    @Bindable var poiViewModel: POIViewModel
    @Bindable var searchViewModel: SearchViewModel
    @Bindable var mapViewModel: MapViewModel
    @Bindable var weatherViewModel: WeatherViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    @Bindable var measurementViewModel: MeasurementViewModel
    @Bindable var offlineViewModel: OfflineViewModel
    @Bindable var sosViewModel: SOSViewModel
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var waypointViewModel: WaypointViewModel
    @Bindable var activityViewModel: ActivityViewModel
    var onSearchResultSelected: (SearchResult) -> Void
    var onStartCustomOfflineSelection: () -> Void
    var onRouteSelected: (Route) -> Void
    var onNewRoute: () -> Void
    var onWaypointEdit: (Waypoint) -> Void
    var onWaypointNavigate: (CLLocationCoordinate2D) -> Void
    var onActivitySelected: (Activity) -> Void
    var onActivityRetrace: (CLLocationCoordinate2D) -> Void
    var onActivityFollow: (Activity) -> Void
    var onStartRecording: () -> Void
    var onDeleteAllData: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavBar(selectedTab: $selectedTab)
                .padding(.bottom, 12)
        }
        .background(Color.Trakke.background)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .home:
            HomeTabContent(
                poiViewModel: poiViewModel,
                searchViewModel: searchViewModel,
                onResultSelected: onSearchResultSelected
            )
        case .navigate:
            NavigateTabContent(
                routeViewModel: routeViewModel,
                waypointViewModel: waypointViewModel,
                activityViewModel: activityViewModel,
                onRouteSelected: onRouteSelected,
                onNewRoute: onNewRoute,
                onWaypointEdit: onWaypointEdit,
                onWaypointNavigate: onWaypointNavigate,
                onActivitySelected: onActivitySelected,
                onActivityRetrace: onActivityRetrace,
                onActivityFollow: onActivityFollow,
                onStartRecording: onStartRecording
            )
        case .tools:
            ToolsTabContent(
                measurementViewModel: measurementViewModel,
                offlineViewModel: offlineViewModel,
                sosViewModel: sosViewModel,
                mapViewModel: mapViewModel,
                onStartCustomOfflineSelection: onStartCustomOfflineSelection
            )
        case .info:
            InfoTabContent(
                weatherViewModel: weatherViewModel,
                knowledgeViewModel: knowledgeViewModel
            )
        case .settings:
            SettingsTabContent(
                mapViewModel: mapViewModel,
                knowledgeViewModel: knowledgeViewModel,
                onDeleteAllData: onDeleteAllData
            )
        }
    }
}
