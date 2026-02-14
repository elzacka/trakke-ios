import SwiftUI

struct RouteListSheet: View {
    @Bindable var viewModel: RouteViewModel
    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.routes.isEmpty {
                    ContentUnavailableView(
                        String(localized: "routes.empty"),
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        description: Text(String(localized: "routes.emptyDescription"))
                    )
                } else {
                    routeList
                }
            }
            .navigationTitle(String(localized: "routes.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onNewRoute?()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "routes.new"))
                }
            }
        }
    }

    private var routeList: some View {
        List {
            ForEach(viewModel.routes, id: \.id) { route in
                Button {
                    onRouteSelected?(route)
                    dismiss()
                } label: {
                    routeRow(route)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteRoute(viewModel.routes[index])
                }
            }
        }
    }

    private func routeRow(_ route: Route) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: route.color ?? "#3e4533"))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(viewModel.formattedDistance(route.distance))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let gain = route.elevationGain, gain > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                            Text("\(Int(gain)) m")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
