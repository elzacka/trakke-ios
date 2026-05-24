import SwiftUI

/// Kategori-velger med gruppering etter ContentGroup. Hver gruppe har
/// sitt eget avsnitt, kategoriene innenfor sortert alfabetisk. Når noe
/// er aktivt vises «Slå av alle» som footer-handling.
struct CategoryPickerSheet: View {
    @Bindable var viewModel: POIViewModel
    @Environment(\.dismiss) private var dismiss

    /// Rekkefølge på grupper — friluftsliv øverst (mest brukt for hiking),
    /// landskap, kulturarv, beredskap sist.
    private static let groupOrder: [ContentGroup] = [
        .friluftsliv, .landskap, .kulturarv, .beredskap,
    ]

    private func categories(in group: ContentGroup) -> [POICategory] {
        POICategory.allCases
            .filter { $0.contentGroup == group }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    ForEach(Self.groupOrder) { group in
                        let cats = categories(in: group)
                        if !cats.isEmpty {
                            groupCard(group: group, categories: cats)
                        }
                    }

                    if !viewModel.enabledCategories.isEmpty {
                        Button {
                            viewModel.disableAllCategories()
                        } label: {
                            Text(String(localized: "categories.disableAll"))
                                .font(Font.Trakke.bodyRegular)
                                .foregroundStyle(Color.Trakke.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, .Trakke.sm)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color.Trakke.background)
            .navigationTitle(String(localized: "categories.title"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.Trakke.brand)
        }
    }

    private func groupCard(group: ContentGroup, categories: [POICategory]) -> some View {
        CardSection(group.displayName) {
            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                    if index > 0 {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    categoryRow(category)
                }
            }
        }
    }

    /// Kategorirad — ikon (her er det funksjonelt: identifiserer kategorien
    /// på kartet), navn, og hake når aktivert. Hele raden er klikkbar.
    private func categoryRow(_ category: POICategory) -> some View {
        let isEnabled = viewModel.enabledCategories.contains(category)
        return Button {
            viewModel.toggleCategory(category)
        } label: {
            HStack(spacing: .Trakke.md) {
                POIIconImage(name: category.iconName, size: 20)
                    .foregroundStyle(Color(hex: category.color))
                    .frame(width: 28, height: 28)

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
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityValue(isEnabled
            ? String(localized: "accessibility.enabled")
            : String(localized: "accessibility.disabled"))
        .accessibilityAddTraits(isEnabled ? .isSelected : [])
    }
}
