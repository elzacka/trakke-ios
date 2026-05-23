import SwiftUI

/// Kategori-hierarki for Hjem-fanen. Viser de fire hovedgruppene
/// (Friluftsliv, Landskap, Kulturarv, Beredskap) som ekspanderbare seksjoner.
/// Hver gruppe åpner en liste over POI-kategorier som kan slås av/på.
struct CategoryHierarchyView: View {
    @Bindable var poiViewModel: POIViewModel
    @State private var expandedGroups: Set<ContentGroup> = []

    /// Rekkefølgen på gruppene som vises — matcher brukerens skisse.
    private let displayedGroups: [ContentGroup] = [
        .friluftsliv,
        .landskap,
        .kulturarv,
        .beredskap,
    ]

    var body: some View {
        VStack(spacing: .Trakke.sm) {
            ForEach(displayedGroups) { group in
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
        }
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
                Divider()
                    .padding(.leading, .Trakke.cardPadH)

                ForEach(Array(categoriesInGroup.enumerated()), id: \.element) { index, category in
                    if index > 0 {
                        Divider()
                            .padding(.leading, .Trakke.cardPadH + 24 + .Trakke.md)
                    }
                    categoryRow(category)
                }
            }
        }
        .background(Color.Trakke.surface)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
    }

    private var headerButton: some View {
        Button(action: {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                onToggleExpanded()
            }
        }) {
            HStack(spacing: .Trakke.md) {
                Image(systemName: group.iconName)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: 24)

                Text(group.displayName)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)

                if enabledCountInGroup > 0 {
                    Text("\(enabledCountInGroup)")
                        .font(Font.Trakke.captionSoft.monospacedDigit())
                        .foregroundStyle(Color.Trakke.textInverse)
                        .padding(.horizontal, .Trakke.sm)
                        .padding(.vertical, 1)
                        .background(Color.Trakke.brand)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(enabledCountInGroup) aktive")
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, .Trakke.cardPadH)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(group.displayName)
        .accessibilityHint(isExpanded ? "Vis mindre" : "Vis kategorier")
        .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)
    }

    private func categoryRow(_ category: POICategory) -> some View {
        let isEnabled = enabledCategories.contains(category)

        return Button(action: { onToggleCategory(category) }) {
            HStack(spacing: .Trakke.md) {
                POIIconImage(name: category.iconName, size: 22)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(width: 24)

                Text(category.displayName)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()

                if isEnabled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.Trakke.brand)
                }
            }
            .padding(.horizontal, .Trakke.cardPadH)
            .padding(.vertical, 12)
            .frame(minHeight: .Trakke.touchMin, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isEnabled ? [.isButton, .isSelected] : .isButton)
    }
}
