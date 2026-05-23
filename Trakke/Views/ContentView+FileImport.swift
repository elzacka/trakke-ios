import SwiftUI

extension ContentView {
    /// Routes an externally opened file (Files / AirDrop / "Open with") into the
    /// appropriate view model and surfaces the matching list sheet.
    ///
    /// GeoJSON is parsed once and dispatched per type to avoid re-decoding. GPX
    /// uses streaming XMLParser per element type — re-parsing is cheap. Activity
    /// takes precedence over Route when track points carry timestamps, since
    /// that's the strongest signal a file is a recording rather than a plan.
    func handleOpenedFile(_ url: URL) {
        var activityCount = 0
        var routeCount = 0
        var waypointCount = 0

        switch url.pathExtension.lowercased() {
        case "geojson", "json":
            do {
                let result = try GeoJSONImportService.parse(from: url)
                let filename = url.importedItemName
                activityCount = activityViewModel.insertImported(result.activities, filename: filename)
                if activityCount == 0 {
                    routeCount = routeViewModel.insertImported(result.routes, filename: filename)
                }
                waypointCount = waypointViewModel.insertImported(result.waypoints, filename: filename)
            } catch {
                routeViewModel.importMessage = String(localized: "routes.importError")
            }
        case "gpx":
            activityCount = activityViewModel.importFile(from: url)
            routeCount = (activityCount > 0) ? 0 : routeViewModel.importFile(from: url)
            waypointCount = waypointViewModel.importFile(from: url)
        default:
            break
        }

        sheets.dismissAll()

        // Multiple types in one file: open the Naviger tab so the user sees
        // the combined overview. Otherwise jump directly to the matching list.
        let typesImported = (activityCount > 0 ? 1 : 0)
            + (routeCount > 0 ? 1 : 0)
            + (waypointCount > 0 ? 1 : 0)
        if typesImported > 1 {
            selectedTab = .navigate
            isFABMenuOpen = true
        } else if activityCount > 0 {
            sheets.active = .activityList
        } else if routeCount > 0 {
            sheets.active = .routeList
        } else if waypointCount > 0 {
            sheets.active = .waypointList
        }
    }
}
