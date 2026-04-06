import SwiftUI

struct MineGreierSheet: View {
    @Bindable var routeViewModel: RouteViewModel
    @Bindable var waypointViewModel: WaypointViewModel
    @Bindable var activityViewModel: ActivityViewModel

    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    var onWaypointSelected: ((Waypoint) -> Void)?
    var onActivitySelected: ((Activity) -> Void)?
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
                            onWaypointSelected: { waypoint in
                                onWaypointSelected?(waypoint)
                                dismiss()
                            },
                            isEmbedded: true,
                            dismissSheet: { dismiss() }
                        )
                    case .activities:
                        ActivityListSheet(
                            viewModel: activityViewModel,
                            onActivitySelected: { activity in
                                onActivitySelected?(activity)
                                dismiss()
                            },
                            onStartRecording: {
                                onStartRecording?()
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
            if navigationPath.count == 0 {
                selectedDetent = .height(280)
            } else {
                selectedDetent = .medium
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
                        destination: .routes
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    menuLink(
                        icon: "mappin",
                        label: String(localized: "mystuff.places"),
                        destination: .waypoints
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    menuLink(
                        icon: "figure.hiking",
                        label: String(localized: "activity.title"),
                        destination: .activities
                    )
                }
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func menuLink(icon: String, label: String, destination: Destination) -> some View {
        Button {
            selectedDetent = .large
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

                Image(systemName: "chevron.right")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
