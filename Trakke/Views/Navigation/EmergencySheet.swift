import SwiftUI
import CoreLocation

/// SOS-sheet – koordinater + nødnumre + signal-aktivering på samme flate.
/// Følger Tråkke-standarden: innebygde overskrifter i hvert felt, ingen
/// info-knapper eller tooltips (veiledning lever i Brukerveiledningen).
struct EmergencySheet: View {
    let userLocation: CLLocation?
    @Bindable var sosViewModel: SOSViewModel
    /// Inline-modus: ingen NavigationStack – kalleren (f.eks. Verktøy-fanen)
    /// gir sin egen navigasjons-kontekst.
    var inline = false
    @State private var numberToCall: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if inline {
            innerContent
        } else {
            NavigationStack {
                innerContent
                    .navigationTitle(String(localized: "emergency.title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(sosViewModel.isActive ? .dark : .light, for: .navigationBar)
                    .toolbarBackground(sosViewModel.isActive ? Color.Trakke.brandDark : Color.Trakke.background, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .interactiveDismissDisabled(sosViewModel.isActive)
        }
    }

    private var innerContent: some View {
        Group {
            if sosViewModel.isActive {
                ActiveSignalView(viewModel: sosViewModel, inline: inline)
            } else {
                inactiveContent
            }
        }
        .background(sosViewModel.isActive ? Color.Trakke.brandDark : Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: sosViewModel.isActive)
        .trakkeDialog(
            isPresented: Binding(
                get: { numberToCall != nil },
                set: { if !$0 { numberToCall = nil } }
            ),
            title: numberToCall.map { String(localized: "emergency.call.confirmTitle \($0)") } ?? "",
            primary: .destructive(String(localized: "common.yes")) {
                if let number = numberToCall,
                   let url = URL(string: "tel://\(number)") {
                    UIApplication.shared.open(url)
                }
            },
            cancel: .cancel(String(localized: "common.no"))
        )
    }

    private var inactiveContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.lg) {
                CoordinatesCard(userLocation: userLocation)

                emergencyNumbersSection

                signalCard

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
            .padding(.bottom, .Trakke.xxl)
        }
    }

    // MARK: - Nødnumre

    private var emergencyNumbersSection: some View {
        CardSection {
            VStack(spacing: 0) {
                emergencyNumberRow(
                    number: "113",
                    label: String(localized: "emergency.numbers.ambulance"),
                    icon: "cross.fill"
                )
                Divider().padding(.leading, .Trakke.dividerLeading)
                emergencyNumberRow(
                    number: "110",
                    label: String(localized: "emergency.numbers.fire"),
                    icon: "flame.fill"
                )
                Divider().padding(.leading, .Trakke.dividerLeading)
                emergencyNumberRow(
                    number: "112",
                    label: String(localized: "emergency.numbers.police"),
                    icon: "shield.fill"
                )
                Divider().padding(.leading, .Trakke.dividerLeading)
                emergencyNumberRow(
                    number: "116117",
                    label: String(localized: "emergency.numbers.legevakt"),
                    icon: "stethoscope"
                )
            }
        }
    }

    private func emergencyNumberRow(number: String, label: String, icon: String) -> some View {
        TrakkeMenuRow(
            icon: icon,
            label: label,
            subtitle: number,
            action: {
                numberToCall = number
            },
            trailing: {
                Image(systemName: "phone.fill")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.brandLight)
            }
        )
        .accessibilityLabel("\(label), \(number)")
        .accessibilityHint(String(localized: "emergency.numbers.callHint"))
    }

    // MARK: - SOS-signal-kort

    /// «Lydsignal»-toggle står igjen i sitt eget kort. «Aktiver SOS»
    /// flyttet ut som en frittstående brandLight-pille – samme stil som
    /// Avstand/Areal/Velg område – slik at handlingen visuelt skiller seg
    /// fra innstillings-toggle, men holdes nær med liten vertikal luft.
    private var signalCard: some View {
        VStack(spacing: .Trakke.sm) {
            CardSection {
                Toggle(isOn: $sosViewModel.audioEnabled) {
                    HStack(spacing: .Trakke.md) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(Color.Trakke.brandLight)
                            .frame(width: 24)
                        Text(String(localized: "sos.audio"))
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.text)
                    }
                }
                .toggleStyle(.trakke)
                .padding(.vertical, 12)
                .frame(minHeight: .Trakke.touchMin)
            }

            Button {
                sosViewModel.activate()
            } label: {
                Text(String(localized: "sos.activate"))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.trakkeSecondary)
            .accessibilityLabel(String(localized: "sos.activate"))

            if !sosViewModel.hasTorch {
                Text(String(localized: "sos.noTorch"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Coordinates Card

private struct CoordinatesCard: View {
    let userLocation: CLLocation?
    @State private var copiedId: String?
    @State private var snapshotLocation: CLLocation?

    private var coordinate: CLLocationCoordinate2D? {
        guard let loc = snapshotLocation,
              loc.coordinate.latitude.isFinite,
              loc.coordinate.longitude.isFinite else { return nil }
        return loc.coordinate
    }

    var body: some View {
        CardSection {
            if let coord = coordinate {
                VStack(spacing: 0) {
                    coordinateField(
                        id: "dd",
                        label: String(localized: "emergency.coordinates.decimal"),
                        formatted: CoordinateService.format(coordinate: coord, format: .dd)
                    )
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    coordinateField(
                        id: "utm",
                        label: "UTM",
                        formatted: CoordinateService.format(coordinate: coord, format: .utm)
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                    Text(String(localized: "emergency.coordinates.noPosition"))
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .Trakke.md)
            }
        }
        .onAppear {
            if let loc = userLocation, loc.coordinate.latitude.isFinite {
                snapshotLocation = loc
            }
        }
        .onChange(of: userLocation) { _, newLoc in
            guard let newLoc, newLoc.coordinate.latitude.isFinite else { return }
            guard let current = snapshotLocation else {
                snapshotLocation = newLoc
                return
            }
            let accuracyImproved = newLoc.horizontalAccuracy < current.horizontalAccuracy - 10
            let movedSignificantly = newLoc.distance(from: current) > 15
            if accuracyImproved || movedSignificantly {
                snapshotLocation = newLoc
            }
        }
    }

    private func coordinateField(id: String, label: String, formatted: FormattedCoordinate) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(label)
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                Text(formatted.display)
                    .font(Font.Trakke.bodyRegular.monospacedDigit())
                    .foregroundStyle(Color.Trakke.text)
                    .accessibilityLabel(formatted.copyText)
            }
            Spacer()
            Button {
                UIPasteboard.general.setItems(
                    [["public.utf8-plain-text": formatted.copyText]],
                    options: [.expirationDate: Date().addingTimeInterval(300)]
                )
                copiedId = id
                Task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    if copiedId == id { copiedId = nil }
                }
            } label: {
                Image(systemName: copiedId == id ? "checkmark" : "doc.on.doc")
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.brandLight)
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.copy"))
        }
        .padding(.vertical, .Trakke.rowVertical)
    }
}

// MARK: - Active SOS Signal

private struct ActiveSignalView: View {
    @Bindable var viewModel: SOSViewModel
    /// Når SOS-skjermen vises inni AppMenuSheet må Stopp-knappen klare
    /// BottomNavBar nederst. Standalone-presentasjon bruker vanlig padding.
    var inline: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: .Trakke.cardGap) {
            Spacer()

            Text("\u{00B7}\u{00B7}\u{00B7} \u{2014} \u{2014} \u{2014} \u{00B7}\u{00B7}\u{00B7}")
                .font(Font.Trakke.morse)
                .foregroundStyle(Color.Trakke.textInverse.opacity(0.9))
                .accessibilityLabel("SOS")

            Text(String(localized: "sos.signalActive"))
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(Color.Trakke.textInverse.opacity(0.85))

            // iOS slår av lommelykten når enheten låses. Skrivingen kaster
            // ikke, den blir bare oversett (bekreftet med isTorchActive på
            // enhet), så dette kan ikke løses i kode – bare sies tydelig.
            if viewModel.hasTorch {
                Text(String(localized: "sos.lockHint"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textInverse.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .Trakke.lg)
            }

            Spacer()

            Button {
                viewModel.deactivate()
            } label: {
                Text(String(localized: "sos.stop"))
                    .font(Font.Trakke.articleSubheading)
                    .foregroundStyle(Color.Trakke.brandDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: .Trakke.touchCTA)
                    .background(Color.Trakke.surface)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            }
            .accessibilityLabel(String(localized: "sos.stop"))
        }
        .padding(.horizontal, .Trakke.sheetHorizontal)
        .padding(.bottom, inline ? .Trakke.bottomNavClearance : .Trakke.xxl)
    }
}
