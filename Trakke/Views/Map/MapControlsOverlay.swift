import SwiftUI

struct MapControlsOverlay<WeatherContent: View>: View {
    @Bindable var viewModel: MapViewModel
    var onSearchTapped: (() -> Void)?
    var onCategoryTapped: (() -> Void)?
    var onMyStuffTapped: (() -> Void)?
    var onWeatherTapped: (() -> Void)?
    var onEmergencyTapped: (() -> Void)?
    var onMoreTapped: (() -> Void)?
    var enabledOverlays: Set<OverlayLayer> = []
    @Binding var isMenuOpen: Bool
    var weatherContent: WeatherContent
    var showCompass = false
    var showZoomControls = false
    var showScaleBar = false
    var hideMenuAndZoom = false
    var isConnected = true
    var isCleanMapActive = false
    var onCleanMapToggle: (() -> Void)?
    var isInsideOfflineArea = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var menuItems: [(icon: String, label: String, action: () -> Void)] {
        [
            ("magnifyingglass", String(localized: "search.title"), { onSearchTapped?() }),
            (viewModel.isTrackingUser ? "location.fill" : "location", String(localized: "map.controls.myPosition"), { viewModel.centerOnUser() }),
            ("square.grid.2x2", String(localized: "categories.title"), { onCategoryTapped?() }),
            ("tray.full", String(localized: "mystuff.title"), { onMyStuffTapped?() }),
            ("light.beacon.max.fill", String(localized: "emergency.title"), { onEmergencyTapped?() }),
            ("cloud.sun", String(localized: "weather.title"), { onWeatherTapped?() }),
            ("ellipsis", String(localized: "more.title"), { onMoreTapped?() }),
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
                        weatherContent
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
        fabButtonLabel
            .onLongPressGesture(minimumDuration: 0.5) {
                guard !isMenuOpen else { return }
                onCleanMapToggle?()
            }
            .onTapGesture {
                withAnimation(reduceMotion ? .none : .spring(duration: 0.3)) {
                    isMenuOpen.toggle()
                }
            }
            .accessibilityLabel(isCleanMapActive
                ? String(localized: "fab.cleanMap.active")
                : String(localized: "fab.menu"))
            .accessibilityHint(String(localized: "fab.cleanMap.hint"))
            .accessibilityAction(named: Text(String(localized: "fab.cleanMap.toggle"))) {
                onCleanMapToggle?()
            }
    }

    private var fabButtonLabel: some View {
        Group {
            if isMenuOpen {
                Image(systemName: "xmark")
                    .font(Font.Trakke.bodyMedium)
            } else if isCleanMapActive {
                Image(systemName: "eye.slash")
                    .font(Font.Trakke.bodyMedium)
            } else {
                Image("ForestIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
        .foregroundStyle(Color.Trakke.textInverse)
        .frame(width: 56, height: 56)
        .background(Color.Trakke.brand)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
        .trakkeFABShadow()
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
                    reduceMotion ? .none : .spring(duration: 0.35).delay(Double(menuItems.count - 1 - index) * 0.03),
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
            HStack(spacing: .Trakke.md) {
                Image(systemName: icon)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: .Trakke.xxl)
                    .accessibilityHidden(true)

                Text(label)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)

                Spacer()
            }
            .padding(.horizontal, .Trakke.lg)
            .frame(height: .Trakke.touchMin)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        }
        .frame(minWidth: 200, maxWidth: 260)
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(Font.Trakke.bodyMedium)
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
                    .font(Font.Trakke.bodyMedium)
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
                .fill(Color.Trakke.text.opacity(0.7))
                .frame(width: scale.widthPt, height: 2)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.Trakke.text.opacity(0.7))
                        .frame(width: 1, height: 6)
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.Trakke.text.opacity(0.7))
                        .frame(width: 1, height: 6)
                }
            Text(scale.label)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.text)
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
            .foregroundStyle(Color.Trakke.textTertiary)
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
                .font(Font.Trakke.bodyMedium)
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
            Image(systemName: isInsideOfflineArea ? "checkmark.circle.fill" : "wifi.slash")
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(isInsideOfflineArea ? Color.Trakke.brand : Color.Trakke.warning)
            Text(isInsideOfflineArea
                ? String(localized: "connectivity.offline.mapAvailable")
                : String(localized: "connectivity.offline"))
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.horizontal, .Trakke.md)
        .padding(.vertical, .Trakke.sm)
        .background(Color.Trakke.background)
        .clipShape(Capsule())
        .trakkeControlShadow()
        .accessibilityLabel(isInsideOfflineArea
            ? String(localized: "connectivity.offline.mapAvailable")
            : String(localized: "connectivity.offline"))
    }
}
