import SwiftUI

/// Centralizes all sheet presentation state for ContentView.
/// Replaces 16 individual @State booleans with a single @Observable coordinator.
@MainActor
@Observable
final class SheetCoordinator {
    var showSearchSheet = false
    var showCategoryPicker = false
    var showPOIDetail = false
    var showRouteList = false
    var showRouteDetail = false
    var showRouteSave = false
    var showWaypointList = false
    var showWaypointDetail = false
    var showWaypointEdit = false
    var editingWaypoint: Waypoint?
    var showOfflineManager = false
    var showDownloadArea = false
    var showWeatherSheet = false
    var showMeasurementSheet = false
    var showPreferences = false
    var showInfo = false
    var showNavigationStart = false

    func dismissAll() {
        showSearchSheet = false
        showCategoryPicker = false
        showPOIDetail = false
        showRouteList = false
        showRouteDetail = false
        showRouteSave = false
        showWaypointList = false
        showWaypointDetail = false
        showWaypointEdit = false
        editingWaypoint = nil
        showOfflineManager = false
        showDownloadArea = false
        showWeatherSheet = false
        showMeasurementSheet = false
        showPreferences = false
        showInfo = false
        showNavigationStart = false
    }
}
