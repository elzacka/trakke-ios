import SwiftUI

/// Kategori-hierarki for Hjem-fanen. Viser hovedgruppene som ekspanderbare
/// rader inni én delt CardSection – samme mønster som Info-fanens akkordeon-
/// grupperinger (Datakilder + Åpen kildekode i Om). Hver gruppe åpner en
/// liste over POI-kategorier som kan slås av/på.
///
/// Stylingen (typografi, vertikal padding, chevron-stil) matcher
/// ExpandableSection. Den eneste forskjellen er at radene har et ledende
/// SF Symbol-ikon for hver hovedgruppe, og en pille med antall aktive
/// kategorier i gruppen.
struct CategoryHierarchyView: View {
    @Bindable var poiViewModel: POIViewModel
    @State private var expandedGroups: Set<ContentGroup> = []

    /// Rekkefølgen på gruppene som vises – matcher brukerens skisse.
    private let displayedGroups: [ContentGroup] = [
        .friluftsliv,
        .landskap,
        .kulturarv,
        .beredskap,
    ]

    var body: some View {
        CardSection {
            VStack(spacing: 0) {
                ForEach(Array(displayedGroups.enumerated()), id: \.element) { index, group in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    CategoryGroupSection(
                        group: group,
                        isExpanded: expandedGroups.contains(group),
                        enabledCategories: poiViewModel.enabledCategories,
                        onToggleExpanded: { toggleExpanded(group) },
                        onToggleCategory: { category in
                            poiViewModel.toggleCategory(category)
                        }
                    )
                }

                if !poiViewModel.enabledCategories.isEmpty {
                    Divider().padding(.leading, .Trakke.dividerLeading)
                    removeAllRow
                }
            }
        }
    }

    /// Fjerner alle kategorier fra kartet. Lå tidligere i `CategoryPickerSheet`,
    /// som ingen kodelinje åpnet – med ti kategorier på måtte du slå av hver
    /// enkelt. Vises bare når det faktisk er noe å fjerne.
    ///
    /// `eye.slash` er appens etablerte symbol for å skjule noe fra kartet, og
    /// står alene: navnet ligger i accessibilityLabel for skjermleser.
    private var removeAllRow: some View {
        Button {
            poiViewModel.disableAllCategories()
        } label: {
            Image(systemName: "eye.slash")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.Trakke.brandLight)
                .frame(maxWidth: .infinity, minHeight: .Trakke.touchMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "categories.disableAll"))
    }

    private func toggleExpanded(_ group: ContentGroup) {
        if expandedGroups.contains(group) {
            expandedGroups.remove(group)
        } else {
            expandedGroups.insert(group)
        }
    }
}

// MARK: - Group Section

private struct CategoryGroupSection: View {
    let group: ContentGroup
    let isExpanded: Bool
    let enabledCategories: Set<POICategory>
    let onToggleExpanded: () -> Void
    let onToggleCategory: (POICategory) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var categoriesInGroup: [POICategory] {
        POICategory.allCases
            .filter { $0.contentGroup == group }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    private var enabledCountInGroup: Int {
        categoriesInGroup.filter { enabledCategories.contains($0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerButton

            if isExpanded {
                Divider().padding(.leading, .Trakke.dividerLeading)

                ForEach(Array(categoriesInGroup.enumerated()), id: \.element) { index, category in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    categoryRow(category)
                }
            }
        }
    }

    /// Header – matcher ExpandableSection's typografi og spacing. Forskjell:
    /// ledende ikon (hovedgruppens SF Symbol) og en valgfri pille med antall
    /// aktive POI-kategorier i gruppen.
    private var headerButton: some View {
        Button(action: {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                onToggleExpanded()
            }
        }) {
            HStack(spacing: .Trakke.md) {
                Image(systemName: group.iconName)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.Trakke.brandLight)
                    .frame(width: 24)

                Text(group.displayName)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                if enabledCountInGroup > 0 {
                    Text("\(enabledCountInGroup)")
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(Color.Trakke.textInverse)
                        .padding(.horizontal, .Trakke.sm)
                        .padding(.vertical, 1)
                        .background(Color.Trakke.brandLight)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(enabledCountInGroup) aktive")
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.textSoft)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.vertical, 12)
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.displayName)
        .accessibilityHint(isExpanded
            ? String(localized: "accessibility.tapToCollapse")
            : String(localized: "accessibility.tapToExpand"))
        .accessibilityAddTraits(isExpanded ? [.isHeader, .isSelected] : .isHeader)
    }

    private func categoryRow(_ category: POICategory) -> some View {
        let isEnabled = enabledCategories.contains(category)

        return Button(action: { onToggleCategory(category) }) {
            HStack(spacing: .Trakke.md) {
                POIIconImage(name: category.iconName, size: 22)
                    .foregroundStyle(Color.Trakke.brandLight)
                    .frame(width: 24)

                Text(category.displayName)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()

                if isEnabled {
                    Image(systemName: "checkmark")
                        .font(Font.Trakke.bodyMedium)
                        .foregroundStyle(Color.Trakke.brandLight)
                }
            }
            .padding(.vertical, 12)
            // Sub-kategorier indenteres litt forbi hovedgruppens
            // ikon-spalte slik at det visuelt fremgår at de er
            // underordnet. 16pt gir tydelig hierarki uten å skyve
            // teksten for langt høyre.
            .padding(.leading, .Trakke.lg)
            .frame(minHeight: .Trakke.touchMin, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isEnabled ? [.isButton, .isSelected] : .isButton)
    }
}
