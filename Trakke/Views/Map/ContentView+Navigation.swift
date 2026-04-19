import SwiftUI
import CoreLocation

extension ContentView {
    func startRouteNavigation(to destination: CLLocationCoordinate2D) {
        guard let userLocation = mapViewModel.userLocation else { return }
        mapViewModel.startNavigation()
        mapViewModel.onLocationUpdate = { [weak navigationViewModel] location in
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
        mapViewModel.onLocationUpdate = { [weak navigationViewModel] location in
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
        mapViewModel.onLocationUpdate = { [weak navigationViewModel] location in
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

    func stopNavigation() {
        navigationViewModel.stopNavigation()
        mapViewModel.stopNavigation()
        navigatingRouteId = nil
        UIApplication.shared.isIdleTimerDisabled = false
        // Restore activity location forwarding if still recording
        if activityViewModel.isRecording {
            mapViewModel.onLocationUpdate = { [weak activityViewModel] location in
                Task { @MainActor in
                    activityViewModel?.processLocation(location)
                }
            }
        }
    }

    // MARK: - Activity Recording

    func startActivityRecording() {
        activityViewModel.startRecording()
        mapViewModel.onLocationUpdate = { [weak activityViewModel] location in
            Task { @MainActor in
                activityViewModel?.processLocation(location)
            }
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }
}
