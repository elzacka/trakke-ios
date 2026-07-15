import SwiftUI

/// Verktøy-fanen — Måleverktøy, Offline kart, SOS.
/// Måleverktøy rendres direkte med to store kort-knapper (Avstand / Areal).
/// Offline og SOS bruker inline-modus av eksisterende sheets, så all
/// flow-logikken (kommune-tre, custom-område-velging, koordinater, signal)
/// gjenbrukes uten dobbel header.
struct ToolsTabContent: View {
    @Bindable var measurementViewModel: MeasurementViewModel
    @Bindable var offlineViewModel: OfflineViewModel
    @Bindable var sosViewModel: SOSViewModel
    @Bindable var mapViewModel: MapViewModel
    var onStartCustomOfflineSelection: () -> Void
    @State private var selectedSubTab: Int = 0
    @Environment(\.dismiss) private var dismiss

    private let subTabs = [
        String(localized: "measurement.title"),
        String(localized: "offline.title"),
        String(localized: "emergency.title"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrakkeSheetHeader(title: String(localized: "appTab.tools"))

                TrakkeUnderlineTabs(
                    titles: subTabs,
                    selectedIndex: $selectedSubTab
                )

                Group {
                    switch selectedSubTab {
                    case 0: measurementContent
                    case 1: offlineContent
                    case 2: emergencyContent
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.Trakke.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Måleverktøy
    //
    // Avstand og Areal er handlinger (start måle-modus + lukk menyen), ikke
    // hierarki — derfor trakkeSecondary-knapper i stedet for chevron-rader.
    // Samme mønster som "Tegn rute"/"Logg tur" på Naviger-fanen.

    private var measurementContent: some View {
        ScrollView {
            VStack(spacing: .Trakke.sm) {
                Button {
                    mapViewModel.searchPinCoordinate = nil
                    measurementViewModel.startMeasuring(mode: .distance)
                    dismiss()
                } label: {
                    Text(String(localized: "measurement.startDistance"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.trakkeSecondary)

                Button {
                    mapViewModel.searchPinCoordinate = nil
                    measurementViewModel.startMeasuring(mode: .area)
                    dismiss()
                } label: {
                    Text(String(localized: "measurement.startArea"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.trakkeSecondary)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.lg)
            .padding(.bottom, .Trakke.xxl + 60)
        }
    }

    // MARK: - Offline kart

    private var offlineContent: some View {
        OfflineSetupSheet(
            viewModel: offlineViewModel,
            onCustom: {
                onStartCustomOfflineSelection()
                dismiss()
            },
            inline: true
        )
    }

    // MARK: - SOS

    private var emergencyContent: some View {
        EmergencySheet(
            userLocation: mapViewModel.userLocation,
            sosViewModel: sosViewModel,
            inline: true
        )
    }
}
