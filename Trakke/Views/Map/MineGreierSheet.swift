import SwiftUI
import CoreLocation

struct MineGreierSheet: View {
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var waypointViewModel: WaypointViewModel
    @Bindable var activityViewModel: ActivityViewModel

    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    var onWaypointSelected: ((Waypoint) -> Void)?
    var onWaypointEdit: ((Waypoint) -> Void)?
    var onWaypointNavigate: ((CLLocationCoordinate2D) -> Void)?
    var onActivitySelected: ((Activity) -> Void)?
    var onActivityRetrace: ((CLLocationCoordinate2D) -> Void)?
    var onActivityFollow: ((Activity) -> Void)?
    var onStartRecording: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    @State private var selectedDetent: PresentationDetent = .height(280)

    enum Destination: Hashable {
        case routes
        case waypoints
        case activities
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            menuList
                .tint(Color.Trakke.brand)
                .navigationTitle(String(localized: "mystuff.title"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .routes:
                        RouteListSheet(
                            viewModel: routeViewModel,
                            onRouteSelected: { route in
                                onRouteSelected?(route)
                                dismiss()
                            },
                            onNewRoute: {
                                onNewRoute?()
                                dismiss()
                            },
                            isEmbedded: true,
                            dismissSheet: { dismiss() }
                        )
                    case .waypoints:
                        WaypointListSheet(
                            viewModel: waypointViewModel,
                            onWaypointSelected: { wp in
                                onWaypointSelected?(wp)
                            },
                            onWaypointEdit: { wp in
                                onWaypointEdit?(wp)
                                dismiss()
                            },
                            onWaypointNavigate: { coord in
                                onWaypointNavigate?(coord)
                                dismiss()
                            },
                            isEmbedded: true,
                            dismissSheet: { dismiss() }
                        )
                    case .activities:
                        ActivityListSheet(
                            viewModel: activityViewModel,
                            routeViewModel: routeViewModel,
                            onActivitySelected: { _ in },
                            onStartRecording: {
                                onStartRecording?()
                                dismiss()
                            },
                            onRetrace: { coord in
                                onActivityRetrace?(coord)
                                dismiss()
                            },
                            onFollowAgain: { activity in
                                onActivityFollow?(activity)
                                dismiss()
                            },
                            isEmbedded: true,
                            dismissSheet: { dismiss() }
                        )
                    }
                }
        }
        .presentationDetents([.height(280), .medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onChange(of: navigationPath.count) {
            // Grow the sheet when navigating into a sub-list, shrink it back to
            // the compact "menu" height when popping back to the root. This is
            // the SINGLE source of truth for detent changes during navigation —
            // do NOT also set selectedDetent in the menu button, that produces
            // two simultaneous state writes which SwiftUI logs as
            // "Update NavigationRequestObserver tried to update multiple times
            // per frame" and causes the first tap to be ignored.
            if navigationPath.count == 0 {
                selectedDetent = .height(280)
            } else {
                selectedDetent = .large
            }
        }
    }

    // MARK: - Menu

    private var menuList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                CardSection {
                    menuLink(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        label: String(localized: "routes.title"),
                        count: routeViewModel.routes.count,
                        destination: .routes
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    menuLink(
                        icon: "mappin",
                        label: String(localized: "mystuff.places"),
                        count: waypointViewModel.waypoints.count,
                        destination: .waypoints
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    menuLink(
                        icon: "figure.hiking",
                        label: String(localized: "activity.title"),
                        count: activityViewModel.activities.count,
                        destination: .activities
                    )
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func menuLink(icon: String, label: String, count: Int, destination: Destination) -> some View {
        Button {
            // Only mutate navigationPath here. The detent is updated by
            // .onChange(of: navigationPath.count) so we never write two pieces
            // of state in the same frame.
            navigationPath.append(destination)
        } label: {
            HStack(spacing: .Trakke.md) {
                Image(systemName: icon)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }

                Image(systemName: "chevron.right")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0
            ? "\(label), \(count)"
            : label)
    }
}
