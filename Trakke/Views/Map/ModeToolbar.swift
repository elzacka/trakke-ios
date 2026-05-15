import SwiftUI

/// Top-level toolbar that swaps based on the current `MapMode`. One
/// composable view replaces three sets of mutually-exclusive booleans
/// in ContentView.
struct ModeToolbar: View {
    let mode: MapMode
    let routeViewModel: RouteViewModel
    let measurementViewModel: MeasurementViewModel
    let offlineViewModel: OfflineViewModel
    let onRouteSave: () -> Void
    let onDownloadArea: () -> Void

    @ViewBuilder
    var body: some View {
        switch mode {
        case .drawing:
            DrawingToolbar(
                pointCount: routeViewModel.drawingCoordinates.count,
                formattedDistance: routeViewModel.formattedDrawingDistance,
                onCancel: { routeViewModel.cancelDrawing() },
                onUndo: { routeViewModel.undoLastPoint() },
                onDone: onRouteSave
            )
        case .measuring:
            MeasurementToolbar(
                mode: measurementViewModel.mode ?? .distance,
                formattedResult: measurementViewModel.formattedResult,
                hasPoints: !measurementViewModel.points.isEmpty,
                onCancel: { measurementViewModel.stop() },
                onUndo: { measurementViewModel.undoLastPoint() },
                onClear: { measurementViewModel.clearAll() }
            )
        case .selecting:
            SelectionToolbar(
                hasValidSelection: offlineViewModel.hasValidSelection,
                estimatedTileCount: offlineViewModel.estimatedTileCount,
                estimatedSize: offlineViewModel.estimatedSize,
                onCancel: { offlineViewModel.cancelSelection() },
                onDone: onDownloadArea
            )
        case .idle, .navigating:
            EmptyView()
        }
    }
}
