import SwiftUI
import CoreLocation

struct EmergencySheet: View {
    let userLocation: CLLocation?
    @Bindable var sosViewModel: SOSViewModel
    @State private var selectedTab: EmergencyTab = .coordinates

    enum EmergencyTab: String, CaseIterable {
        case coordinates
        case signal

        var label: String {
            switch self {
            case .coordinates: return String(localized: "emergency.tab.coordinates")
            case .signal: return String(localized: "emergency.tab.signal")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !sosViewModel.isActive {
                    Picker("", selection: $selectedTab) {
                        ForEach(EmergencyTab.allCases, id: \.self) { tab in
                            Text(tab.label).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, .Trakke.sheetHorizontal)
                    .padding(.top, .Trakke.md)
                    .padding(.bottom, .Trakke.md)
                }

                switch selectedTab {
                case .coordinates:
                    CoordinatesContent(userLocation: userLocation)
                case .signal:
                    SOSContent(viewModel: sosViewModel)
                }
            }
            .background(sosViewModel.isActive ? Color.Trakke.brandDark : Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "emergency.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(sosViewModel.isActive ? .dark : .light, for: .navigationBar)
            .toolbarBackground(sosViewModel.isActive ? Color.Trakke.brandDark : Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(sosViewModel.isActive)
        }
    }
}

// MARK: - Coordinates Content

private struct CoordinatesContent: View {
    let userLocation: CLLocation?
    @State private var copiedId: String?
    @State private var showCoordinateInfo = false

    private var coordinate: CLLocationCoordinate2D? {
        guard let loc = userLocation,
              loc.coordinate.latitude.isFinite,
              loc.coordinate.longitude.isFinite else { return nil }
        return loc.coordinate
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                if let coord = coordinate {
                    coordinateCards(for: coord)
                } else {
                    noPositionView
                }

                HStack {
                    Spacer()
                    Button {
                        showCoordinateInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(Font.Trakke.caption)
                            .foregroundStyle(Color.Trakke.textTertiary)
                    }
                    .accessibilityLabel(String(localized: "emergency.coordinates.infoLabel"))
                    .trakkeTooltip(isPresented: $showCoordinateInfo) {
                        TrakkeTooltip(
                            title: "",
                            text: String(localized: "emergency.coordinates.instruction")
                        )
                    }
                }

                emergencyNumbersSection

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sm)
        }
    }

    @ViewBuilder
    private func coordinateCards(for coord: CLLocationCoordinate2D) -> some View {
        let utm = CoordinateService.format(coordinate: coord, format: .utm)
        let dd = CoordinateService.format(coordinate: coord, format: .dd)

        CardSection(String(localized: "emergency.coordinates.decimal")) {
            coordinateRow(id: "dd", formatted: dd)
        }

        CardSection("UTM") {
            coordinateRow(id: "utm", formatted: utm)
        }

        if let accuracy = userLocation?.horizontalAccuracy, accuracy > 0 {
            Text(String(localized: "emergency.coordinates.accuracy \(Int(accuracy))"))
                .font(Font.Trakke.caption)
                .foregroundStyle(Color.Trakke.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func coordinateRow(id: String, formatted: FormattedCoordinate) -> some View {
        HStack(alignment: .center) {
            Text(formatted.display)
                .font(Font.Trakke.title)
                .foregroundStyle(Color.Trakke.text)
                .accessibilityLabel(formatted.copyText)

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
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.copy"))
        }
    }

    private var noPositionView: some View {
        CardSection("") {
            VStack(spacing: .Trakke.sm) {
                Image(systemName: "location.slash")
                    .font(Font.Trakke.title)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .accessibilityHidden(true)
                Text(String(localized: "emergency.coordinates.noPosition"))
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .Trakke.xl)
        }
    }


    // MARK: - Emergency Numbers

    private var emergencyNumbersSection: some View {
        CardSection(String(localized: "emergency.numbers.title")) {
            VStack(spacing: 0) {
                emergencyNumberRow(
                    number: "113",
                    label: String(localized: "emergency.numbers.ambulance"),
                    icon: "cross.fill",
                    isFirst: true
                )
                Divider().padding(.leading, .Trakke.touchMin)
                emergencyNumberRow(
                    number: "110",
                    label: String(localized: "emergency.numbers.fire"),
                    icon: "flame.fill"
                )
                Divider().padding(.leading, .Trakke.touchMin)
                emergencyNumberRow(
                    number: "112",
                    label: String(localized: "emergency.numbers.police"),
                    icon: "shield.fill"
                )
                Divider().padding(.leading, .Trakke.touchMin)
                emergencyNumberRow(
                    number: "116117",
                    label: String(localized: "emergency.numbers.legevakt"),
                    icon: "stethoscope"
                )
            }
        }
    }

    private func emergencyNumberRow(
        number: String,
        label: String,
        icon: String,
        isFirst: Bool = false
    ) -> some View {
        Button {
            guard let url = URL(string: "tel://\(number)") else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: .Trakke.md) {
                Image(systemName: icon)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: .Trakke.touchMin)

                VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                    Text(number)
                        .font(Font.Trakke.title)
                        .foregroundStyle(Color.Trakke.text)
                    Text(label)
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSecondary)
                }

                Spacer()

                Image(systemName: "phone.fill")
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.brand)
            }
            .padding(.vertical, .Trakke.sm)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(label), \(number)")
        .accessibilityHint(String(localized: "emergency.numbers.callHint"))
    }

}

// MARK: - SOS Content

private struct SOSContent: View {
    @Bindable var viewModel: SOSViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var morseSize: CGFloat = 28
    @State private var showSOSInfo = false

    var body: some View {
        VStack(spacing: .Trakke.cardGap) {
            if viewModel.isActive {
                Spacer()
                activeState
                Spacer()
            } else {
                inactiveState
                Spacer(minLength: .Trakke.lg)
            }
        }
        .padding(.horizontal, .Trakke.sheetHorizontal)
        .padding(.top, .Trakke.sm)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: viewModel.isActive)
    }

    private var inactiveState: some View {
        VStack(spacing: .Trakke.lg) {
            HStack {
                Spacer()
                Button {
                    showSOSInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
                .accessibilityLabel(String(localized: "sos.infoLabel"))
                .trakkeTooltip(isPresented: $showSOSInfo) {
                    TrakkeTooltip(
                        title: "",
                        text: String(localized: "sos.description")
                    )
                }
            }

            Toggle(isOn: $viewModel.audioEnabled) {
                Label {
                    Text(String(localized: "sos.audio"))
                        .font(Font.Trakke.bodyRegular)
                } icon: {
                    Image(systemName: "speaker.wave.2")
                }
            }
            .tint(Color.Trakke.brand)
            .padding(.horizontal, .Trakke.lg)

            Button {
                viewModel.activate()
            } label: {
                Text(String(localized: "sos.activate"))
                    .font(Font.Trakke.title).bold()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: .Trakke.touchCTA)
                    .background(Color.Trakke.brand)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            }
            .accessibilityLabel(String(localized: "sos.activate"))
        }
    }

    private var activeState: some View {
        VStack(spacing: .Trakke.lg) {
            Text("\u{00B7}\u{00B7}\u{00B7} \u{2014} \u{2014} \u{2014} \u{00B7}\u{00B7}\u{00B7}")
                .font(Font.Trakke.morse)
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityLabel("SOS")

            Text(String(localized: "sos.signalActive"))
                .font(Font.Trakke.bodyMedium)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                viewModel.deactivate()
            } label: {
                Text(String(localized: "sos.stop"))
                    .font(Font.Trakke.title).bold()
                    .foregroundStyle(Color.Trakke.brandDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: .Trakke.touchCTA)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.xl))
            }
            .accessibilityLabel(String(localized: "sos.stop"))
        }
    }

}
