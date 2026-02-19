import SwiftUI

struct MapControlsOverlay: View {
    @Bindable var viewModel: MapViewModel
    var onSearchTapped: (() -> Void)?
    var onCategoryTapped: (() -> Void)?
    var onRouteTapped: (() -> Void)?
    var onMyPlacesTapped: (() -> Void)?
    var onOfflineTapped: (() -> Void)?
    var onWeatherTapped: (() -> Void)?
    var onMeasurementTapped: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onInfoTapped: (() -> Void)?
    var enabledOverlays: Set<OverlayLayer> = []
    var weatherWidget: AnyView?
    var showCompass = false
    var showZoomControls = false
    var showScaleBar = false
    var hideMenuAndZoom = false
    var isConnected = true

    @State private var isMenuOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var menuItems: [(icon: String, label: String, action: () -> Void)] {
        [
            ("magnifyingglass", String(localized: "search.title"), { onSearchTapped?() }),
            (viewModel.isTrackingUser ? "location.fill" : "location", String(localized: "map.controls.myPosition"), { viewModel.centerOnUser() }),
            ("point.topleft.down.to.point.bottomright.curvepath", String(localized: "routes.title"), { onRouteTapped?() }),
            ("mappin", String(localized: "waypoints.title"), { onMyPlacesTapped?() }),
            ("square.grid.2x2", String(localized: "categories.title"), { onCategoryTapped?() }),
            ("cloud.sun", String(localized: "weather.title"), { onWeatherTapped?() }),
            ("ruler", String(localized: "measurement.title"), { onMeasurementTapped?() }),
            ("arrow.down.circle", String(localized: "offline.title"), { onOfflineTapped?() }),
            ("gearshape", String(localized: "settings.title"), { onSettingsTapped?() }),
            ("info.circle", String(localized: "info.title"), { onInfoTapped?() }),
        ]
    }

    var body: some View {
        ZStack {
            if isMenuOpen {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(reduceMotion ? .none : .spring(duration: 0.3)) { isMenuOpen = false }
                    }
            }

            VStack {
                if !isConnected {
                    offlineChip
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: .Trakke.sm) {
                        if showCompass {
                            compassButton
                        }
                        if let weatherWidget {
                            weatherWidget
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, .Trakke.xxl)
            .padding(.top, .Trakke.sm)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: isConnected)

            VStack {
                Spacer()

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: .Trakke.rowVertical) {
                        if showScaleBar {
                            scaleBar
                        }
                        attributionText
                    }

                    Spacer()

                    if !hideMenuAndZoom {
                        VStack(alignment: .trailing, spacing: .Trakke.md) {
                            if isMenuOpen {
                                fabMenuContent
                            } else {
                                if showZoomControls {
                                    zoomControls
                                }
                            }

                            fabButton
                        }
                    }
                }
                .padding(.horizontal, .Trakke.xxl)
                .padding(.bottom, .Trakke.sm)
            }
        }
    }

    // MARK: - FAB Button

    private var fabButton: some View {
        Button {
            withAnimation(reduceMotion ? .none : .spring(duration: 0.3)) {
                isMenuOpen.toggle()
            }
        } label: {
            Group {
                if isMenuOpen {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                } else {
                    Image("ForestIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Color.Trakke.brand)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            .trakkeFABShadow()
        }
        .accessibilityLabel(String(localized: "fab.menu"))
    }

    // MARK: - FAB Menu Items

    private var fabMenuContent: some View {
        VStack(alignment: .trailing, spacing: .Trakke.sm) {
            ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                fabMenuItem(icon: item.icon, label: item.label) {
                    item.action()
                    withAnimation(reduceMotion ? .none : .spring(duration: 0.3)) { isMenuOpen = false }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(
                    .spring(duration: 0.35).delay(Double(menuItems.count - 1 - index) * 0.03),
                    value: isMenuOpen
                )
            }
        }
    }

    private func fabMenuItem(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: .Trakke.lg, weight: .medium))
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: .Trakke.xxl)

                Text(label)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: .Trakke.touchMin)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        }
        .frame(minWidth: 180, maxWidth: 240)
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: .Trakke.lg, weight: .medium))
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
            }
            .accessibilityLabel(String(localized: "map.controls.zoomIn"))

            Divider()
                .frame(width: 28)

            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: .Trakke.lg, weight: .medium))
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
            }
            .accessibilityLabel(String(localized: "map.controls.zoomOut"))
        }
        .background(Color.Trakke.background)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))
        .trakkeControlShadow()
    }

    // MARK: - Scale Bar

    private var scaleBar: some View {
        let scale = scaleInfo
        return HStack(spacing: .Trakke.xs) {
            Rectangle()
                .fill(Color.primary.opacity(0.7))
                .frame(width: scale.widthPt, height: 2)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.7))
                        .frame(width: 1, height: 6)
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.7))
                        .frame(width: 1, height: 6)
                }
            Text(scale.label)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, .Trakke.sm)
        .padding(.vertical, .Trakke.xs)
        .background(Color.Trakke.background)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
        .trakkeControlShadow()
    }

    private var scaleInfo: (widthPt: CGFloat, label: String) {
        let lat = viewModel.currentCenter.latitude
        let zoom = viewModel.currentZoom
        let metersPerPixel = 156543.03392 * cos(lat * .pi / 180) / pow(2, zoom)
        let targetMeters = metersPerPixel * 80

        let niceValues: [Double] = [
            10, 20, 50, 100, 200, 500,
            1_000, 2_000, 5_000, 10_000, 20_000, 50_000,
            100_000, 200_000, 500_000, 1_000_000
        ]
        let snapped = niceValues.min(by: { abs($0 - targetMeters) < abs($1 - targetMeters) }) ?? targetMeters
        let barWidth = snapped / metersPerPixel

        let label: String
        if snapped >= 1_000 {
            label = "\(Int(snapped / 1_000)) km"
        } else {
            label = "\(Int(snapped)) m"
        }

        return (widthPt: CGFloat(max(30, min(barWidth, 120))), label: label)
    }

    // MARK: - Attribution

    private var attributionText: some View {
        let parts = [MapConstants.attribution] +
            enabledOverlays
                .sorted { $0.rawValue < $1.rawValue }
                .compactMap { overlay in
                    overlay.attribution == MapConstants.attribution ? nil : overlay.attribution
                }
        let text = parts.joined(separator: " | ")
        return Text(text)
            .font(Font.Trakke.captionSoft)
            .foregroundStyle(Color.Trakke.textSoft)
            .padding(.horizontal, .Trakke.sm)
            .padding(.vertical, .Trakke.xs)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
    }

    // MARK: - Compass

    private var compassButton: some View {
        Button {
            viewModel.shouldResetHeading = true
        } label: {
            Image(systemName: "location.north.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.Trakke.text)
                .rotationEffect(.degrees(-viewModel.currentHeading))
                .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                .background(Color.Trakke.background)
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.md))
                .trakkeControlShadow()
        }
        .accessibilityLabel(String(localized: "map.controls.compass"))
    }

    // MARK: - Offline Chip

    private var offlineChip: some View {
        HStack(spacing: .Trakke.xs) {
            Image(systemName: "wifi.slash")
                .font(.caption2)
            Text(String(localized: "connectivity.offline"))
                .font(Font.Trakke.caption)
        }
        .foregroundStyle(Color.Trakke.textSoft)
        .padding(.horizontal, .Trakke.md)
        .padding(.vertical, .Trakke.sm)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .trakkeControlShadow()
    }
}
