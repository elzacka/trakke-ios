import SwiftUI

struct MapControlsOverlay<WeatherContent: View>: View {
    @Bindable var viewModel: MapViewModel
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
    var isNavigating = false
    var navigationCameraMode: NavigationCameraMode = .northUp
    var onToggleCameraMode: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCleanMapHint = false

    var body: some View {
        ZStack {
            VStack {
                if !isConnected {
                    offlineChip
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.horizontal, .Trakke.xxl)
            .padding(.top, .Trakke.sm)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: isConnected)

            VStack {
                Spacer()

                HStack(alignment: .bottom) {
                    // Bunn venstre: målestokk over Kartverket-attribusjon, samme stil
                    VStack(alignment: .leading, spacing: .Trakke.rowVertical) {
                        if showScaleBar {
                            scaleBar
                        }
                        attributionText
                    }

                    Spacer()

                    // Bunn høyre: alle innstillings-styrte knapper + FAB nederst.
                    // Dynamisk posisjonering – VStack skipper rader som ikke vises,
                    // så FAB ligger alltid på samme stable plassering uansett hvilke
                    // overlay-knapper som er aktive. Vises også under navigasjon
                    // og andre kart-modi.
                    VStack(alignment: .trailing, spacing: .Trakke.sm) {
                        if showCompass {
                            compassButton
                        }
                        weatherContent
                        if showZoomControls && !isMenuOpen {
                            zoomControls
                        }
                        fabButton
                    }
                }
                .padding(.horizontal, .Trakke.xxl)
                .padding(.bottom, .Trakke.sm)
            }

            // Kort hint når rent-kart slås på – trykk og hold kan trigges utilsiktet
            // (f.eks. med hansker), og eneste andre signal er at ikonet endres.
            if showCleanMapHint {
                VStack {
                    Spacer()
                    Text(String(localized: "map.cleanMap.hint"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial)
                        .clipShape(.capsule)
                    Spacer()
                    Spacer()
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .task(id: isCleanMapActive) {
            guard isCleanMapActive else { return }
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                showCleanMapHint = true
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                showCleanMapHint = false
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
            .accessibilityAddTraits(.isButton)
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

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel(String(localized: "map.controls.zoomIn"))

            Divider()
                .frame(width: 36)

            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel(String(localized: "map.controls.zoomOut"))
        }
        .background(Color.Trakke.surface)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
        .trakkeControlShadow()
    }

    // MARK: - Scale Bar

    private var scaleBar: some View {
        let scale = scaleInfo
        return HStack(spacing: .Trakke.xs) {
            Rectangle()
                .fill(Color.Trakke.textTertiary)
                .frame(width: scale.widthPt, height: 2)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.Trakke.textTertiary)
                        .frame(width: 1, height: 6)
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.Trakke.textTertiary)
                        .frame(width: 1, height: 6)
                }
            Text(scale.label)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.horizontal, .Trakke.sm)
        .padding(.vertical, .Trakke.xs)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
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

    private var isHeadingUpActive: Bool {
        isNavigating ? navigationCameraMode == .courseUp : viewModel.isHeadingUp
    }

    /// Kompass + retnings-veksler. Tapper:
    /// - Under navigasjon: veksler mellom nord-opp og retning-opp via kamera-modus.
    /// - Ellers: slår heading-up av/på og sentrerer på brukeren.
    /// Ikon-fargen signalerer aktiv tilstand (grønn = retning-opp, rød = nord-opp).
    private var compassButton: some View {
        Button {
            if isNavigating {
                onToggleCameraMode?()
            } else if viewModel.isHeadingUp {
                viewModel.isHeadingUp = false
                viewModel.shouldResetHeading = true
                viewModel.centerOnUser()
            } else {
                viewModel.isHeadingUp = true
                viewModel.centerOnUser()
            }
        } label: {
            Image(systemName: "location.north.fill")
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(isHeadingUpActive ? Color.Trakke.brand : Color.Trakke.red)
                .rotationEffect(.degrees(-viewModel.currentHeading))
                .frame(width: 56, height: 56)
                .background(Color.Trakke.surface)
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
                .trakkeControlShadow()
        }
        .accessibilityLabel(isHeadingUpActive
            ? String(localized: "map.controls.compass.courseUp")
            : String(localized: "map.controls.compass"))
        .accessibilityHint(String(localized: "map.controls.myPosition"))
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
        .background(Color.Trakke.surface)
        .clipShape(Capsule())
        .trakkeControlShadow()
        .accessibilityLabel(isInsideOfflineArea
            ? String(localized: "connectivity.offline.mapAvailable")
            : String(localized: "connectivity.offline"))
    }
}
