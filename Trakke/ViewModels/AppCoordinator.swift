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

    /// Navigér kompass til siste punkt på ruten.
    func startFollowingRoute(_ route: Route) {
        guard let last = route.coordinates.last, last.count >= 2 else { return }
        let destination = CLLocationCoordinate2D(latitude: last[1], longitude: last[0])
        startCompassNavigation(to: destination)
    }

    /// Navigér kompass til siste GPS-punkt i aktiviteten.
    func followActivity(_ activity: Activity) {
        guard let last = activity.trackPoints.last, last.count >= 2,
              last[0].isFinite, last[1].isFinite else { return }
        let destination = CLLocationCoordinate2D(latitude: last[1], longitude: last[0])
        startCompassNavigation(to: destination)
    }

    func stopNavigation() {
        navigationViewModel.stopNavigation()
        mapViewModel.stopNavigation()
        UIApplication.shared.isIdleTimerDisabled = activityViewModel.isRecording || sosViewModel.isActive
    }

    func toggleNavigationCamera() {
        navigationViewModel.toggleCameraMode()
    }

    // MARK: - Activity recording

    func startActivityRecording() {
        // Gate on location permission; primer is shown by startTrackingLocation.
        let status = mapViewModel.locationAuthStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            mapViewModel.startTrackingLocation()
            return
        }
        // CLLocationManager leverer ingen posisjoner før startUpdatingLocation
        // er kalt – uten denne linjen samler et opptak startet uten aktiv
        // kartsporing null punkter og turen går tapt ved lagring.
        mapViewModel.startTrackingLocation()
        // Et opptak må overleve at skjermen låser seg. Uten dette sluttet
        // posisjonene å komme i det brukeren la telefonen i lomma, og turen
        // ble en stump av seg selv – uten at noe varslet om det.
        mapViewModel.claimBackgroundLocation("recording")
        mapViewModel.setLocationObserver("recording") { [weak activityViewModel] location in
            Task { @MainActor in
                activityViewModel?.processLocation(location)
            }
        }
        activityViewModel.startRecording()
        activityViewModel.onRecordingStop = { [weak self] in
            self?.handleRecordingStop()
        }
        // Skjermen holdes ikke lenger våken gjennom hele turen. Den vanen kom
        // av at opptaket stoppet ved skjermlås; nå gjør det ikke det, og et
        // batteri som varer hele turen er verdt mer enn et tent display.
        UIApplication.shared.isIdleTimerDisabled = navigationViewModel.isActive || sosViewModel.isActive
    }

    /// Gjenopptar et opptak som ble avbrutt av at appen døde. Samme oppsett
    /// som et nytt opptak – observatør, bakgrunnsposisjon, stopp-håndtering –
    /// bare med sporet som allerede finnes.
    func resumeInterruptedRecording() {
        mapViewModel.startTrackingLocation()
        mapViewModel.claimBackgroundLocation("recording")
        mapViewModel.setLocationObserver("recording") { [weak activityViewModel] location in
            Task { @MainActor in
                activityViewModel?.processLocation(location)
            }
        }
        activityViewModel.onRecordingStop = { [weak self] in
            self?.handleRecordingStop()
        }
        activityViewModel.resumeInterruptedRecording()
    }

    // MARK: - Handlinger bestilt utenfra

    /// Lagrer posisjonen som et sted, med tidspunktet som navn.
    ///
    /// Uten en kjent posisjon lages ingenting. Et sted med gjettet posisjon er
    /// verre enn ikke noe sted, særlig når hensikten er å finne tilbake.
    func markCurrentPlace() {
        guard let coordinate = mapViewModel.userLocation?.coordinate else {
            mapViewModel.startTrackingLocation()
            waypointViewModel.saveError = String(localized: "intent.noLocation")
            return
        }
        let name = Date.now.formatted(date: .abbreviated, time: .shortened)
        waypointViewModel.addWaypoint(name: name, coordinate: coordinate, category: nil)
        HapticFeedback.success()
    }

    private func handleRecordingStop() {
        mapViewModel.removeLocationObserver("recording")
        mapViewModel.releaseBackgroundLocation("recording")
        activityViewModel.onRecordingStop = nil
        UIApplication.shared.isIdleTimerDisabled = navigationViewModel.isActive || sosViewModel.isActive
    }

    // MARK: - GDPR

    /// Tøm alle cacher som kan inneholde brukerdata. Kalles fra
    /// «Slett alle data»-flyten i innstillinger.
    func clearAllServiceCaches() {
        // Et pågående opptak er brukerdata: stopp det først, ellers skriver
        // sporings-aktoren journalen tilbake ved neste sjekkpunkt.
        if activityViewModel.isRecording {
            activityViewModel.stopWithoutSaving()
        }
        GPXExportService.clearAllExports()
        // Journalen for et pågående opptak er turdata på disk og må med her,
        // ellers overlever et halvferdig spor en full sletting.
        ActivityRecordingJournal.clear()
        activityViewModel.discardInterruptedRecording()

        // Refetch post-delete so no view keeps holding deleted PersistentModel instances.
        routeViewModel.loadRoutes()
        waypointViewModel.loadWaypoints()
        activityViewModel.loadActivities()
        routeViewModel.clearSelection()
        waypointViewModel.selectedWaypoint = nil  // can hold a deleted model too

        Task { [weak self] in
            guard let self else { return }
            await self.weatherViewModel.clearCaches()
            await self.searchViewModel.clearCaches()
            await self.routeViewModel.clearCaches()
            await self.poiViewModel.clearCaches()
            await self.waypointViewModel.clearCaches()
            self.knowledgeViewModel.clearCache()
        }
    }
}
