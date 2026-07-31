import SwiftUI

/// De fem hovedfanene som vises i den flytende bunn-nav-baren.
/// Hver fane mapper til ett sheet-innhold som presenteres når menyen er åpen.
enum AppTab: Hashable, CaseIterable {
    case home
    case navigate
    case tools
    case info
    case settings

    var icon: String {
        switch self {
        case .home: "house"
        case .navigate: "paperplane"
        case .tools: "wrench.and.screwdriver"
        case .info: "lightbulb"
        case .settings: "gearshape"
        }
    }

    var iconFilled: String {
        switch self {
        case .home: "house.fill"
        case .navigate: "paperplane.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .info: "lightbulb.fill"
        case .settings: "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .home: String(localized: "appTab.home")
        case .navigate: String(localized: "appTab.navigate")
        case .tools: String(localized: "appTab.tools")
        case .info: String(localized: "appTab.info")
        case .settings: String(localized: "appTab.settings")
        }
    }
}

/// Flytende bunn-nav-bar inspirert av AllTrails – pille-formet container
/// med fem ikon-knapper. Synlig kun når brukeren har åpnet appmenyen via FAB.
struct BottomNavBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, .Trakke.xs)
        .padding(.vertical, .Trakke.xs)
        .background(Color.Trakke.surface)
        .clipShape(Capsule())
        .trakkeFABShadow()
        .padding(.horizontal, .Trakke.lg)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = (tab == selectedTab)

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: isActive ? tab.iconFilled : tab.icon)
                .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isActive ? Color.Trakke.brand : Color.Trakke.textSecondary)
                .frame(maxWidth: .infinity, minHeight: .Trakke.touchMin)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var tab: AppTab = .home
    return ZStack(alignment: .bottom) {
        Color.Trakke.background.ignoresSafeArea()
        BottomNavBar(selectedTab: $tab)
            .padding(.bottom, 24)
    }
}
