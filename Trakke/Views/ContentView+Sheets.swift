import SwiftUI

extension ContentView {

    @ViewBuilder
    func sheetContent(for active: ActiveSheet) -> some View {
        switch active {
        case .search:
            SearchSheet(
                viewModel: searchViewModel,
                onResultSelected: { result in
                    mapViewModel.searchPinCoordinate = result.coordinate
                    mapViewModel.centerOn(coordinate: result.coordinate, zoom: 14)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .categoryPicker:
            CategoryPickerSheet(viewModel: poiViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)

        case .poiDetail:
            if let poi = poiViewModel.selectedPOI {
                POIDetailSheet(
                    poi: poi,
                    onNavigate: { coordinate in
                        navigationDestination = coordinate
                        sheets.active = .navigationStart
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }

        case .routeList:
            RouteListSheet(
                viewModel: routeViewModel,
                onRouteSelected: { route in
                    sheets.active = nil
                    startFollowingRoute(route)
                },
                onNewRoute: {
                    routeViewModel.startDrawing()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .routeSave:
            RouteSaveSheet(viewModel: routeViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)

        case .waypointList:
            WaypointListSheet(
                viewModel: waypointViewModel,
                onWaypointSelected: { _ in },
                onWaypointEdit: { wp in
                    sheets.editingWaypoint = wp
                    sheets.active = .waypointEdit
                },
                onWaypointNavigate: { coordinate in
                    navigationDestination = coordinate
                    sheets.active = .navigationStart
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .waypointDetail:
            if let wp = waypointViewModel.selectedWaypoint {
                WaypointDetailSheet(
                    viewModel: waypointViewModel,
                    waypoint: wp,
                    onEdit: { waypoint in
                        sheets.editingWaypoint = waypoint
                        sheets.active = .waypointEdit
                    },
                    onNavigate: { coordinate in
                        navigationDestination = coordinate
                        sheets.active = .navigationStart
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }

        case .waypointEdit:
            WaypointEditSheet(
                viewModel: waypointViewModel,
                editingWaypoint: sheets.editingWaypoint
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)

        case .offlineManager:
            DownloadManagerSheet(
                viewModel: offlineViewModel,
                onNewDownload: {
                    sheets.active = .offlineSetup
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .downloadArea:
            DownloadAreaSheet(viewModel: offlineViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .offlineSetup:
            OfflineSetupSheet(
                viewModel: offlineViewModel,
                onCustom: {
                    offlineViewModel.startSelection(
                        center: mapViewModel.currentCenter,
                        zoom: mapViewModel.currentZoom
                    )
                }
            )

        case .weather:
            WeatherSheet(viewModel: weatherViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

        case .measurement:
            MeasurementSheet(viewModel: measurementViewModel)
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)

        case .navigationStart:
            if let dest = navigationDestination {
                NavigationStartSheet(
                    destination: dest,
                    userLocation: mapViewModel.userLocation,
                    isConnected: connectivityMonitor.isConnected,
                    onRouteNavigation: { startRouteNavigation(to: dest) },
                    onCompassNavigation: { startCompassNavigation(to: dest) }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }

        case .emergency:
            EmergencySheet(
                userLocation: mapViewModel.userLocation,
                sosViewModel: sosViewModel
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onDisappear { sosViewModel.deactivate() }

        case .activityList:
            ActivityListSheet(
                viewModel: activityViewModel,
                routeViewModel: routeViewModel,
                onActivitySelected: { _ in },
                onStartRecording: {
                    startActivityRecording()
                },
                onRetrace: { coordinate in
                    navigationDestination = coordinate
                    sheets.active = .navigationStart
                },
                onFollowAgain: { activity in
                    sheets.active = nil
                    followActivity(activity)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)

        case .activitySave:
            ActivitySaveSheet(viewModel: activityViewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}
