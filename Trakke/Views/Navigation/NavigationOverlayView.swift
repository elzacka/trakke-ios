import SwiftUI

struct NavigationOverlayView: View {
    let navigationVM: NavigationViewModel
    let userHeading: Double?
    let isConnected: Bool
    var onStop: () -> Void
    var onSwitchToCompass: () -> Void
    var onSwitchToRoute: () -> Void
    var onToggleCamera: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var compassArrowSize: CGFloat = 48

    var body: some View {
        VStack {
            Spacer()

            if navigationVM.isOffTrack {
                DeviationChipView(
                    distance: navigationVM.offTrackDistance,
                    onDismiss: { navigationVM.dismissDeviation() }
                )
            }

            if navigationVM.hasArrived {
                arrivalBanner
                    .onAppear {
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: String(localized: "navigation.arrived")
                        )
                    }
            }

            VStack(spacing: 0) {
                switch navigationVM.mode {
                case .route:
                    routeHUD
                case .compass:
                    compassHUD
                }

                Divider()
                actionBar
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.bottom, .Trakke.sm)
        }
        .safeAreaPadding(.bottom)
    }

    // MARK: - Route HUD

    private var routeHUD: some View {
        VStack(spacing: .Trakke.sm) {
            if let progress = navigationVM.progress {
                HStack(spacing: 0) {
                    statCell(
                        label: String(localized: "navigation.remaining"),
                        value: formatDistance(progress.distanceRemaining)
                    )
                    Divider().frame(height: 36)
                    statCell(
                        label: String(localized: "navigation.elevationRemaining"),
                        value: "+\(Int(progress.elevationGainRemaining)) m"
                    )
                    Divider().frame(height: 36)
                    statCell(
                        label: String(localized: "navigation.timeRemaining"),
                        value: formatTime(progress.estimatedTimeRemaining)
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(statsAccessibilityLabel(progress))

                ProgressView(value: progress.fractionCompleted)
                    .tint(Color.Trakke.brand)
                    .padding(.horizontal, .Trakke.cardPadH)
                    .accessibilityLabel(String(localized: "navigation.progress"))
                    .accessibilityValue("\(Int(progress.fractionCompleted * 100)) %")

                gpsIndicator
                    .padding(.horizontal, .Trakke.cardPadH)
            }

            if let instruction = navigationVM.nextInstruction {
                Divider()
                HStack(spacing: .Trakke.sm) {
                    Image(systemName: turnIcon(instruction.type))
                        .font(.title3)
                        .foregroundStyle(Color.Trakke.brand)
                        .frame(width: 32)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(instruction.text)
                            .font(Font.Trakke.bodyMedium)
                            .lineLimit(3)
                        if let progress = navigationVM.progress {
                            let distToTurn = instruction.distance - (progress.totalDistance - progress.distanceRemaining)
                            if distToTurn > 0 {
                                Text(formatDistance(distToTurn))
                                    .font(Font.Trakke.caption)
                                    .foregroundStyle(Color.Trakke.textTertiary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, .Trakke.cardPadH)
                .padding(.vertical, .Trakke.sm)
            }

        }
        .padding(.top, .Trakke.cardPadV)
    }

    // MARK: - Compass HUD

    private var compassHUD: some View {
        VStack(spacing: .Trakke.md) {
            let relativeBearing = computeRelativeBearing()
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: compassArrowSize))
                .foregroundStyle(Color.Trakke.brand)
                .rotationEffect(.degrees(relativeBearing))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.3),
                    value: relativeBearing
                )
                .accessibilityLabel(
                    String(localized: "navigation.bearing")
                        + ": \(Int(navigationVM.compassBearing))\u{00B0}"
                )

            VStack(spacing: .Trakke.xs) {
                Text(formatDistance(navigationVM.compassDistance))
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(Color.Trakke.brand)

                Text(bearingText(navigationVM.compassBearing))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }

            gpsIndicator
        }
        .padding(.vertical, .Trakke.cardPadV)
        .padding(.horizontal, .Trakke.cardPadH)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            switch navigationVM.mode {
            case .route:
                Button {
                    navigationVM.reverseRoute()
                } label: {
                    Label(String(localized: "navigation.reverse"), systemImage: "arrow.uturn.right")
                        .font(Font.Trakke.bodyRegular)
                        .labelStyle(.iconOnly)
                }
                .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                .accessibilityLabel(String(localized: "navigation.reverse"))

                Button {
                    onSwitchToCompass()
                } label: {
                    Label(String(localized: "navigation.switchToCompass"), systemImage: "safari")
                        .font(Font.Trakke.bodyRegular)
                        .labelStyle(.iconOnly)
                }
                .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                .accessibilityLabel(String(localized: "navigation.switchToCompass"))

                Button {
                    onToggleCamera()
                } label: {
                    Image(systemName: navigationVM.cameraMode == .northUp
                          ? "location.north" : "location.north.line")
                        .font(Font.Trakke.bodyRegular)
                }
                .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                .accessibilityLabel(
                    navigationVM.cameraMode == .northUp
                        ? String(localized: "navigation.cameraMode.courseUp")
                        : String(localized: "navigation.cameraMode.northUp")
                )

            case .compass:
                if isConnected {
                    Button {
                        onSwitchToRoute()
                    } label: {
                        Label(
                            String(localized: "navigation.switchToRoute"),
                            systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                        )
                        .font(Font.Trakke.bodyRegular)
                    }
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                }
            }

            Spacer()

            Button(role: .destructive) {
                onStop()
            } label: {
                Text(String(localized: "navigation.stopNavigation"))
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.red)
            }
            .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
        }
        .padding(.horizontal, .Trakke.cardPadH)
        .padding(.vertical, .Trakke.sm)
    }

    // MARK: - GPS Indicator

    @ViewBuilder
    private var gpsIndicator: some View {
        switch navigationVM.gpsQuality {
        case .good:
            EmptyView()
        case .reduced:
            HStack(spacing: .Trakke.xs) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(Font.Trakke.captionSoft)
                Text(String(localized: "navigation.gpsReduced"))
                    .font(Font.Trakke.captionSoft)
            }
            .foregroundStyle(Color.Trakke.yellow)
        case .lost:
            HStack(spacing: .Trakke.xs) {
                Image(systemName: "location.slash")
                    .font(Font.Trakke.captionSoft)
                Text(String(localized: "navigation.gpsLost"))
                    .font(Font.Trakke.captionSoft)
            }
            .foregroundStyle(Color.Trakke.red)
        }
    }

    // MARK: - Arrival Banner

    private var arrivalBanner: some View {
        Text(String(localized: "navigation.arrived"))
            .font(Font.Trakke.bodyMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(Color.Trakke.brand)
            .clipShape(Capsule())
            .padding(.bottom, .Trakke.sm)
    }

    // MARK: - Helpers

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Font.Trakke.captionSoft)
                .foregroundStyle(Color.Trakke.textTertiary)
            Text(value)
                .font(Font.Trakke.bodyRegular.monospacedDigit().bold())
                .foregroundStyle(Color.Trakke.brand)
        }
        .frame(maxWidth: .infinity)
    }

    private func statsAccessibilityLabel(_ progress: NavigationProgress) -> String {
        let distance = formatDistance(progress.distanceRemaining)
        let elevation = "+\(Int(progress.elevationGainRemaining)) m"
        let time = formatTime(progress.estimatedTimeRemaining)
        return "\(distance) \(String(localized: "navigation.remaining")), \(elevation) \(String(localized: "navigation.elevationRemaining")), \(time) \(String(localized: "navigation.timeRemaining"))"
    }

    private func formatDistance(_ meters: Double) -> String {
        MeasurementService.formatDistance(meters)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours) t \(minutes) min"
        }
        return "\(minutes) min"
    }

    private func computeRelativeBearing() -> Double {
        let heading = userHeading ?? 0
        return navigationVM.compassBearing - heading
    }

    private func bearingText(_ degrees: Double) -> String {
        let n = ((degrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let direction: String
        switch n {
        case 337.5..<360, 0..<22.5: direction = "N"
        case 22.5..<67.5: direction = "N\u{00D8}"
        case 67.5..<112.5: direction = "\u{00D8}"
        case 112.5..<157.5: direction = "S\u{00D8}"
        case 157.5..<202.5: direction = "S"
        case 202.5..<247.5: direction = "SV"
        case 247.5..<292.5: direction = "V"
        case 292.5..<337.5: direction = "NV"
        default: direction = ""
        }
        return "\(Int(n))\u{00B0} (\(direction))"
    }

    private func turnIcon(_ type: TurnType) -> String {
        switch type {
        case .straight: return "arrow.up"
        case .slightRight: return "arrow.up.right"
        case .right: return "arrow.turn.up.right"
        case .sharpRight: return "arrow.turn.down.right"
        case .slightLeft: return "arrow.up.left"
        case .left: return "arrow.turn.up.left"
        case .sharpLeft: return "arrow.turn.down.left"
        case .uTurn: return "arrow.uturn.down"
        case .destination: return "flag.fill"
        case .depart: return "figure.walk"
        case .ferry: return "ferry.fill"
        case .other: return "arrow.up"
        }
    }
}
