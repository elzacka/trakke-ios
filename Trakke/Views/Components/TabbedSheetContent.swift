import SwiftUI

/// Container som komponerer en sheet med:
/// - TrakkeSheetHeader (drag-handle + stor tittel + close-X)
/// - TrakkeUnderlineTabs (PWA-stil underline)
/// - Scrollable innhold per tab
///
/// Brukes som rotnode for Naviger / Verktøy / Info-fanene.
struct TabbedSheetContent<Content: View>: View {
    let title: String
    let tabTitles: [String]
    @Binding var selectedIndex: Int
    @ViewBuilder var content: (Int) -> Content

    var body: some View {
        VStack(spacing: 0) {
            TrakkeSheetHeader(title: title)

            TrakkeUnderlineTabs(
                titles: tabTitles,
                selectedIndex: $selectedIndex
            )

            ScrollView {
                content(selectedIndex)
                    .padding(.horizontal, .Trakke.sheetHorizontal)
                    .padding(.top, .Trakke.lg)
                    .padding(.bottom, .Trakke.xxl + 60)
            }
        }
        .background(Color.Trakke.background)
    }
}
