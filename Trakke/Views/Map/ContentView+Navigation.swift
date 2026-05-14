import SwiftUI
import CoreLocation

extension ContentView {
    func startRouteNavigation(to destination: CLLocationCoordinate2D) {
        guard let userLocation = mapViewModel.userLocation else { return }
        mapViewModel.startNavigation()
        mapViewModel.setLocationObserver("navigation") { [weak navigationViewModel] location in
            Task { @MainActor in
                await navigationViewModel?.processLocationUpdate(location)
            }
        }
        Task { @MainActor in
            let success = await navigationViewModel.startRouteNavigation(
                from: userLocation.coordinate, to: destination
            )
            if success {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                mapViewModel.stopNavigation()
                showRouteError = true
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

    /// "Følg igjen": Navigate along a previously recorded activity by treating its
    /// coordinates as a transient route. The transient Route is in-memory only
    /// and not persisted to SwiftData; navigation logic doesn't distinguish.
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
        // The recording observer (if any) is registered under a separate key, so
        // stopping navigation no longer wipes it. No re-install needed.
    }

    // MARK: - Activity Recording

    func startActivityRecording() {
        activityViewModel.startRecording()
        mapViewModel.setLocationObserver("recording") { [weak activityViewModel] location in
            Task { @MainActor in
                activityViewModel?.processLocation(location)
            }
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }
}
