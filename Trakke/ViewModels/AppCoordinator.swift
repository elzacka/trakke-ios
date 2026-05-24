import CoreLocation
import Observation
import UIKit

/// App-nivå state-container. Eier alle ViewModels og navigasjons-/recording-
/// orkestrering slik at `ContentView` ikke trenger å holde 14 `@State`-
/// felter eller drive navigasjon fra view-laget.
///
/// **Hvorfor `let` på ViewModels?** Properties som er objekt-referanser
/// endrer seg aldri etter init. Indre `@Observable`-properties på hver
/// ViewModel trigger view-oppdatering via SwiftUI sin observasjon.
@MainActor
@Observable
final class AppCoordinator {
    // MARK: - ViewModels

    let mapViewModel: MapViewModel
    let searchViewModel: SearchViewModel
    let poiViewModel: POIViewModel
    let routeViewModel: RouteViewModel
    let waypointViewModel: WaypointViewModel
    let offlineViewModel: OfflineViewModel
    let weatherViewModel: WeatherViewModel
    let measurementViewModel: MeasurementViewModel
    let navigationViewModel: NavigationViewModel
    let sosViewModel: SOSViewModel
    let activityViewModel: ActivityViewModel
    let knowledgeViewModel: KnowledgeViewModel

    // MARK: - Navigation state

    /// Route-ID som blir fulgt akkurat nå (tegnes ikke som vanlig overlay,
    /// men som aktiv navigasjons-trasé).
    var navigatingRouteId: String?
    /// Trigger for rute-feil-dialog (server-feil, ingen rute funnet osv.).
    var showRouteError = false
    /// Vises etter ~250 ms debounce mens Valhalla beregner rute, så den
    /// ikke flimrer for raske svar (~120 ms).
    var showRouteComputingIndicator = false
    /// Trigger for "Stopp navigasjon?"-dialog.
    var showStopConfirmation = false

    init() {
        // Splittet i tre grupper for å holde init() under
        // type-check-budsjettet (200 ms). En enkelt blokk med 12
        // assignments tar ~240 ms; tre grupper á fire kommer godt under.
        (mapViewModel, searchViewModel, poiViewModel, routeViewModel) = Self.makeMapGroup()
        (waypointViewModel, offlineViewModel, weatherViewModel, measurementViewModel) = Self.makeContentGroup()
        (navigationViewModel, sosViewModel, activityViewModel, knowledgeViewModel) = Self.makeActionGroup()
    }

    private static func makeMapGroup() -> (
        MapViewModel, SearchViewModel, POIViewModel, RouteViewModel
    ) {
        (MapViewModel(), SearchViewModel(), POIViewModel(), RouteViewModel())
    }

    private static func makeContentGroup() -> (
        WaypointViewModel, OfflineViewModel, WeatherViewModel, MeasurementViewModel
    ) {
        (WaypointViewModel(), OfflineViewModel(), WeatherViewModel(), MeasurementViewModel())
    }

    private static func makeActionGroup() -> (
        NavigationViewModel, SOSViewModel, ActivityViewModel, KnowledgeViewModel
    ) {
        (NavigationViewModel(), SOSViewModel(), ActivityViewModel(), KnowledgeViewModel())
    }

    // MARK: - Navigation

    func startRouteNavigation(to destination: CLLocationCoordinate2D) {
        guard let userLocation = mapViewModel.userLocation else { return }
        mapViewModel.startNavigation()
        mapViewModel.setLocationObserver("navigation") { [weak navigationViewModel] location in
            Task { @MainActor in
                await navigationViewModel?.processLocationUpdate(location)
            }
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await self.navigationViewModel.startRouteNavigation(
                from: userLocation.coordinate, to: destination
            )
            if success {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                self.mapViewModel.stopNavigation()
                self.showRouteError = true
            }
        }
    }

    func startCompassNavigation(to destination: CLLocationCoordinate2D) {
        mapViewModel.startNavigation()
        mapViewModel.setLocationObserver("navigation") { [weak navigationViewModel] location in
            Task { @MainActor in
                await navigationViewModel?.processLocationUpdate(location)
            }
        }
        navigationViewModel.startCompassNavigation(to: destination)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func startFollowingRoute(_ route: Route) {
        navigatingRouteId = route.id
        mapViewModel.startNavigation()
        mapViewModel.setLocationObserver("navigation") { [weak navigationViewModel] location in
            Task { @MainActor in
                await navigationViewModel?.processLocationUpdate(location)
            }
        }
        navigationViewModel.startFollowingRoute(
            route: route,
            elevationProfile: routeViewModel.elevationProfile
        )
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// "Følg igjen": Navigate along a previously recorded activity by treating
    /// its coordinates as a transient route. The transient Route is in-memory
    /// only and not persisted to SwiftData; navigation logic doesn't distinguish.
    func followActivity(_ activity: Activity) {
        let coords = activity.trackPoints.compactMap { point -> [Double]? in
            guard point.count >= 2 else { return nil }
            let lon = point[0]
            let lat = point[1]
            guard lon.isFinite, lat.isFinite else { return nil }
            return [lon, lat]
        }
        guard coords.count >= 2 else { return }
        let transient = Route(name: activity.name)
        transient.coordinates = coords
        transient.distance = activity.distance
        transient.elevationGain = activity.elevationGain
        transient.elevationLoss = activity.elevationLoss
        startFollowingRoute(transient)
    }

    func stopNavigation() {
        navigationViewModel.stopNavigation()
        mapViewModel.stopNavigation()
        navigatingRouteId = nil
        UIApplication.shared.isIdleTimerDisabled = false
        // The recording observer (if any) is registered under a separate key,
        // so stopping navigation no longer wipes it. No re-install needed.
    }

    func switchToCompassNavigation() {
        navigationViewModel.switchToCompass()
    }

    func switchToRouteNavigation() {
        guard !navigationViewModel.isComputingRoute,
              let userLoc = mapViewModel.userLocation,
              let dest = navigationViewModel.destination else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await self.navigationViewModel.startRouteNavigation(
                from: userLoc.coordinate, to: dest
            )
            if !success {
                self.stopNavigation()
                self.showRouteError = true
            }
        }
    }

    func toggleNavigationCamera() {
        navigationViewModel.toggleCameraMode()
    }

    func requestNavigationReroute() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let success = await self.navigationViewModel.requestReroute()
            if !success { self.showRouteError = true }
        }
    }

    // MARK: - Activity recording

    func startActivityRecording() {
        activityViewModel.startRecording()
        mapViewModel.setLocationObserver("recording") { [weak activityViewModel] location in
            Task { @MainActor in
                activityViewModel?.processLocation(location)
            }
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    // MARK: - GDPR

    /// Tøm alle cacher som kan inneholde brukerdata. Kalles fra
    /// «Slett alle data»-flyten i innstillinger.
    func clearAllServiceCaches() {
        // GDPR: clear exported files synchronously since they may contain
        // user-visible route/activity data (GPX).
        GPXExportService.clearAllExports()
        Task { [weak self] in
            guard let self else { return }
            await self.weatherViewModel.clearCaches()
            await self.searchViewModel.clearCaches()
            await self.routeViewModel.clearCaches()
            await self.poiViewModel.clearCaches()
            await self.waypointViewModel.clearCaches()
            self.knowledgeViewModel.deleteAllPacks()
        }
    }
}
