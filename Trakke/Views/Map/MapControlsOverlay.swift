import SwiftUI

struct MapControlsOverlay<WeatherContent: View>: View {
    @Bindable var viewModel: MapViewModel
    var enabledOverlays: Set<OverlayLayer> = []
    @Binding var isMenuOpen: Bool
    var weatherContent: WeatherContent
    var showCompass = false
    var showZoomControls = false
    var showScaleBar = false
    var showZoomLevel = false
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
    @State private var shownCameraModeHint: MapCameraFollowMode?

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
                        if showScaleBar || showZoomLevel {
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
            if let mode = shownCameraModeHint {
                // Ikonene er nye for brukeren. En kort etikett navngir modusen
                // du nettopp slo på, så formen læres. Vises aldri for «fritt» –
                // at kartet står fritt er selvforklarende når du selv dro i det.
                Text(mode.localizedName)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textInverse)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .Trakke.lg)
                    .padding(.vertical, .Trakke.sm)
                    .background(Color.Trakke.brand)
                    .clipShape(Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 80)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            if showCleanMapHint {
                // Samme stil og plassering som info-chipene i OfflineToasts.
                Text(String(localized: "map.cleanMap.hint"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textInverse)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .Trakke.lg)
                    .padding(.vertical, .Trakke.sm)
                    .background(Color.Trakke.brand)
                    .clipShape(Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 80)
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
        .task(id: followMode) {
            // `.free` navngis ikke: en pan er sin egen forklaring, og et varsel
            // på hver eneste kartflytting ville vært støy.
            guard followMode != .free, !isCleanMapActive else { return }
            let mode = followMode
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                shownCameraModeHint = mode
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                shownCameraModeHint = nil
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

    /// Målestokk og zoomnivå i samme pille. Begge har egen bryter i
    /// Innstillinger, og pillen viser det som er slått på – én, begge eller
    /// ingen. De hører sammen fordi de svarer på samme spørsmål: hvor mye
    /// kart ser jeg, og hvor tett er detaljene.
    private var scaleBar: some View {
        let scale = scaleInfo
        return HStack(spacing: .Trakke.xs) {
            if showScaleBar {
                scaleRule(width: scale.widthPt)

                Text(scale.label)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }

            if showZoomLevel {
                // Avrundet nedover, ikke til nærmeste: terskler sjekkes med
                // `zoom >= minZoom` på den brøkne verdien, så «z12» skal bety
                // «du har passert 12», ikke «du er i nærheten av 12».
                Text("z\(scale.zoom)")
                    .font(Font.Trakke.captionSoft.monospacedDigit())
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
        }
        .padding(.horizontal, .Trakke.sm)
        .padding(.vertical, .Trakke.xs)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "map.scale.a11y"))
        .accessibilityValue(scaleAccessibilityValue(scale))
    }

    private func scaleRule(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.Trakke.textTertiary)
            .frame(width: width, height: 2)
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
    }

    private func scaleAccessibilityValue(
        _ scale: (widthPt: CGFloat, label: String, zoom: Int)
    ) -> String {
        var parts: [String] = []
        if showScaleBar { parts.append(scale.label) }
        if showZoomLevel {
            parts.append("\(String(localized: "map.zoomLevel")) \(scale.zoom)")
        }
        return parts.joined(separator: ", ")
    }


    private var scaleInfo: (widthPt: CGFloat, label: String, zoom: Int) {
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

        return (
            widthPt: CGFloat(max(30, min(barWidth, 120))),
            label: label,
            zoom: Int(zoom.rounded(.down))
        )
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
            // Teksten vokser med påslåtte kartlag («© Kartverket | © NVE»),
            // så UI-testen kan ikke slå opp på hele strengen. Identifikatoren
            // holder oppslaget stabilt; testen sjekker at teksten *begynner*
            // med den påkrevde Kartverket-krediteringen.
            .accessibilityIdentifier("map.attribution")
            .font(Font.Trakke.captionSoft)
            .foregroundStyle(Color.Trakke.textTertiary)
            .padding(.horizontal, .Trakke.sm)
            .padding(.vertical, .Trakke.xs)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.sm))
    }

    // MARK: - Compass

    var followMode: MapCameraFollowMode {
        MapCameraFollowMode.current(
            isCameraDetached: viewModel.isCameraDetached,
            isNavigating: isNavigating,
            navigationCameraMode: navigationCameraMode,
            isTrackingUser: viewModel.isTrackingUser,
            isHeadingUp: viewModel.isHeadingUp
        )
    }

    /// Farge er forsterkning, ikke bærer: grå når kartet står fritt, grønn når
    /// det følger deg. Den gamle rød/grønn-vekslingen mellom nord-opp og
    /// retning-opp er borte – de to skilles nå på ikonets form, som er lesbart
    /// også for de som ikke skiller rødt fra grønt.
    private var compassTint: Color {
        followMode == .free ? Color.Trakke.textTertiary : Color.Trakke.brand
    }

    /// Kompass + følgemodus, samme tredeling som lokasjonsknappen i Apples Kart.
    ///
    /// Rekkefølgen er bevisst ulik i de to bruksmåtene, fordi hviletilstanden
    /// er motsatt: utenfor navigasjon er fritt kart det normale og følging et
    /// avbrekk, under navigasjon er det omvendt.
    /// - Fritt kart: ett trykk henter kameraet tilbake til den modusen du
    ///   hadde. Det bytter ikke modus i tillegg – ett trykk gjør én ting.
    /// - Følger, utenfor navigasjon: trykk veksler nord opp ↔ retning opp.
    /// - Følger, under navigasjon: trykk veksler kameramodus (samme veksling,
    ///   men eid av navigasjonen slik at den overlever HUD-en).
    private var compassButton: some View {
        Button {
            switch followMode {
            case .free:
                viewModel.centerOnUser()
            case .followNorth:
                if isNavigating {
                    onToggleCameraMode?()
                } else {
                    viewModel.isHeadingUp = true
                    viewModel.centerOnUser()
                }
            case .followHeading:
                if isNavigating {
                    onToggleCameraMode?()
                } else {
                    viewModel.isHeadingUp = false
                    viewModel.shouldResetHeading = true
                    viewModel.centerOnUser()
                }
            }
        } label: {
            Image(systemName: followMode.symbolName)
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(compassTint)
                // Nålen peker mot nord i alle tre modusene – det er den ene
                // opplysningen som gjelder uansett hva kameraet gjør.
                .rotationEffect(.degrees(-viewModel.currentHeading))
                .frame(width: 56, height: 56)
                .background(Color.Trakke.surface)
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
                .trakkeControlShadow()
        }
        .accessibilityLabel(String(localized: "map.camera.a11yLabel"))
        .accessibilityValue(followMode.localizedName)
        .accessibilityHint(String(localized: "map.camera.a11yHint"))
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
