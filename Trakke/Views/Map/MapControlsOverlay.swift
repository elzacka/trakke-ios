import SwiftUI

struct MapControlsOverlay: View {
    @Bindable var viewModel: MapViewModel
    var onSearchTapped: (() -> Void)?
    var onCategoryTapped: (() -> Void)?

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

            // Layer picker
            Menu {
                ForEach(BaseLayer.allCases) { layer in
                    Button {
                        viewModel.switchLayer(to: layer)
                    } label: {
                        HStack {
                            Text(layer.displayName)
                            if viewModel.baseLayer == layer {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "map")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(String(localized: "settings.baseLayer"))
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
