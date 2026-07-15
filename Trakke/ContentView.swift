import SwiftUI
import SwiftData
import CoreLocation

/// Interaktiv modus for hovedkartet. Bare én av gangen.
/// Rekkefølgen i `from(...)` definerer prioritet ved konflikt.
enum MapMode: Equatable {
    case idle
    case drawing
    case measuring
    case selecting
    case navigating

    static func from(
        isDrawing: Bool,
        isMeasuring: Bool,
        isSelecting: Bool,
        isNavigating: Bool
    ) -> MapMode {
        if isNavigating { return .navigating }
        if isSelecting { return .selecting }
        if isDrawing { return .drawing }
        if isMeasuring { return .measuring }
        return .idle
    }
}

/// Root-view. Komponerer hovedkartet (MapScreen) med fire modifiers som
/// hver eier ett tydelig ansvar:
/// - `SheetHost` – all sheet-presentasjon (hovedark + FAB-meny)
/// - `DialogHost` – app-nivå dialoger (feilmeldinger, trykk-og-hold-meny)
/// - `AppLifecycleModifier` – onAppear/onDisappear/onChange/task
///
/// State-eierskap er fordelt:
/// - `AppCoordinator` eier ViewModels, navigasjons-state og app-handlinger
/// - `SheetCoordinator` eier hvilken sheet som er aktiv
/// - `ConnectivityMonitor` eier nettverks-status
/// - ContentView eier transient view-state (FAB-meny åpen, clean-map,
///   trykk-og-hold-koordinat, nav-destinasjon) som krysser flere modifiers
struct ContentView: View {
    @State var coordinator = AppCoordinator()
    @State var sheets = SheetCoordinator()
    @State var connectivityMonitor = ConnectivityMonitor()

    @State var isFABMenuOpen = false
    @State var selectedTab: AppTab = .home
    @State var sheetDetent: PresentationDetent = .large
    /// Non-nil while the long-press confirmation dialog is presented for the
    /// given coordinate. Nil dismisses the dialog.
    @State var longPressCoordinate: CLLocationCoordinate2D?
    @State var showDbRecoveryAlert = false
    @State var isCleanMapActive = false

    var body: some View {
        MapScreen(
            coordinator: coordinator,
            sheets: sheets,
            connectivityMonitor: connectivityMonitor,
            isFABMenuOpen: $isFABMenuOpen,
            isCleanMapActive: $isCleanMapActive,
            longPressCoordinate: $longPressCoordinate
        )
        .tint(Color.Trakke.brand)
        .modifier(SheetHost(
            coordinator: coordinator,
            sheets: sheets,
            connectivityMonitor: connectivityMonitor,
            isFABMenuOpen: $isFABMenuOpen,
            selectedTab: $selectedTab,
            sheetDetent: $sheetDetent
        ))
        .modifier(DialogHost(
            coordinator: coordinator,
            sheets: sheets,
            longPressCoordinate: $longPressCoordinate,
            showDbRecoveryAlert: $showDbRecoveryAlert
        ))
        .modifier(AppLifecycleModifier(
            coordinator: coordinator,
            sheets: sheets,
            connectivityMonitor: connectivityMonitor,
            isFABMenuOpen: $isFABMenuOpen,
            selectedTab: $selectedTab,
            sheetDetent: $sheetDetent,
            showDbRecoveryAlert: $showDbRecoveryAlert
        ))
        .onOpenURL(perform: handleOpenedFile)
    }
}

#Preview {
    ContentView()
}
