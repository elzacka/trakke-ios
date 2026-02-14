import SwiftUI

struct MapControlsOverlay: View {
    @Bindable var viewModel: MapViewModel
    var onSearchTapped: (() -> Void)?
    var onCategoryTapped: (() -> Void)?
    var onRouteTapped: (() -> Void)?
    var onOfflineTapped: (() -> Void)?
    var onWeatherTapped: (() -> Void)?
    var onMeasurementTapped: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onInfoTapped: (() -> Void)?
    var weatherWidget: AnyView?

    var body: some View {
        VStack {
            HStack {
                Spacer()
                controlStack
            }
            .padding(.trailing, 16)
            .padding(.top, 8)

            Spacer()

            HStack {
                attributionText
                Spacer()
                zoomLevel
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var controlStack: some View {
        VStack(spacing: 12) {
            // Weather widget
            if let weatherWidget {
                weatherWidget
            }

            // Search button
            Button {
                onSearchTapped?()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "search.title"))

            // Location button
            Button {
                viewModel.centerOnUser()
            } label: {
                Image(systemName: viewModel.isTrackingUser ? "location.fill" : "location")
                    .font(.system(size: 20))
                    .foregroundStyle(viewModel.isTrackingUser ? Color.Trakke.brand : .primary)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "map.controls.myPosition"))

            // Routes button
            Button {
                onRouteTapped?()
            } label: {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "routes.title"))

            // Category picker
            Button {
                onCategoryTapped?()
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "categories.title"))

            // Measurement
            Button {
                onMeasurementTapped?()
            } label: {
                Image(systemName: "ruler")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "measurement.title"))

            // Offline maps
            Button {
                onOfflineTapped?()
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "offline.title"))

            // Settings
            Button {
                onSettingsTapped?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "settings.title"))

            // Info
            Button {
                onInfoTapped?()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "info.title"))
        }
    }

    private var attributionText: some View {
        Text(MapConstants.attribution)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var zoomLevel: some View {
        Text("Z\(Int(viewModel.currentZoom))")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
