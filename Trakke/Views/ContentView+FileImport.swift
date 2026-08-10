import SwiftUI

extension ContentView {
    /// Routes an externally opened file (Files / AirDrop / "Open with") into the
    /// appropriate view model and surfaces the matching list sheet.
    ///
    /// Parsing runs off the MainActor (`importFileAsync` / `Task.detached`) so
    /// the UI stays responsive while a large file is read. GeoJSON is parsed
    /// once and dispatched per type to avoid re-decoding. Activity takes
    /// precedence over Route when track points carry timestamps, since that's
    /// the strongest signal a file is a recording rather than a plan.
    func handleOpenedFile(_ url: URL) {
        Task {  // handleOpenedFile is MainActor-isolated; Task {} inherits it.
            var activityCount = 0
            var routeCount = 0
            var waypointCount = 0

            switch url.pathExtension.lowercased() {
            case "geojson", "json":
                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        try GeoJSONImportService.parse(from: url)
                    }.value
                    let filename = url.importedItemName
                    activityCount = coordinator.activityViewModel.insertImported(result.activities, filename: filename)
                    if activityCount == 0 {
                        routeCount = coordinator.routeViewModel.insertImported(result.routes, filename: filename)
                    }
                    waypointCount = coordinator.waypointViewModel.insertImported(result.waypoints, filename: filename)
                } catch {
                    // do/catch, not try? – preserves the importMessage error
                    // surfacing that try? would silently swallow.
                    coordinator.routeViewModel.importMessage = String(localized: "routes.importError")
                }
            case "gpx":
                activityCount = await coordinator.activityViewModel.importFileAsync(from: url)
                routeCount = (activityCount > 0) ? 0 : await coordinator.routeViewModel.importFileAsync(from: url)
                waypointCount = await coordinator.waypointViewModel.importFileAsync(from: url)
            default:
                break
            }

            // Capture BEFORE dismissing, and defer the menu one runloop turn –
            // same pattern SheetCoordinator.present uses internally.
            let sheetWasOpen = sheets.active != nil
            sheets.dismissAll()

            // Multiple types in one file: open the Naviger tab so the user sees
            // the combined overview. Otherwise jump directly to the matching list.
            let hasActivity: Int = activityCount > 0 ? 1 : 0
            let hasRoute: Int = routeCount > 0 ? 1 : 0
            let hasWaypoint: Int = waypointCount > 0 ? 1 : 0
            let typesImported = hasActivity + hasRoute + hasWaypoint
            if typesImported > 1 {
                selectedTab = .navigate
                if sheetWasOpen {
                    DispatchQueue.main.async { isFABMenuOpen = true }
                } else {
                    isFABMenuOpen = true
                }
            } else if activityCount > 0 || routeCount > 0 {
                presentAfterImport(.tracks)
            } else if waypointCount > 0 {
                presentAfterImport(.waypointList)
            }
        }
    }

    /// En fil kan komme inn mens menyen eller et annet ark står åpent – appen
    /// åpnes jo av iOS med filen. Se `SheetCoordinator.present`.
    private func presentAfterImport(_ sheet: ActiveSheet) {
        let menuWasOpen = isFABMenuOpen
        isFABMenuOpen = false
        sheets.present(sheet, otherSheetIsOpen: menuWasOpen)
    }
}
