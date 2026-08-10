import SwiftUI

/// Innstillinger-fanen – bruker eksisterende PreferencesSheet i inline-modus
/// for å gjenbruke alle togglerne, koordinatformat og slett-alle-data-flyt.
/// TrakkeSheetHeader på toppen erstatter iOS-default `.navigationTitle`.
/// NavigationStack beholdes for fremtidige push-destinasjoner; selve
/// slett-alle-data-bekreftelsen vises som dialog inne i PreferencesSheet.
struct SettingsTabContent: View {
    @Bindable var mapViewModel: MapViewModel
    @Bindable var knowledgeViewModel: KnowledgeViewModel
    var onDeleteAllData: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrakkeSheetHeader()

                ScrollView {
                    PreferencesSheet(
                        mapViewModel: mapViewModel,
                        knowledgeViewModel: knowledgeViewModel,
                        onDeleteAllData: onDeleteAllData,
                        inline: true
                    )
                    .padding(.bottom, .Trakke.xxl + 60)
                }
            }
            .background(Color.Trakke.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
