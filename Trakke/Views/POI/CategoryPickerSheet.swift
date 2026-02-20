import SwiftUI

struct CategoryPickerSheet: View {
    @Bindable var viewModel: POIViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    CardSection(String(localized: "categories.title")) {
                        let sorted = POICategory.allCases.sorted {
                            $0.displayName.localizedCompare($1.displayName) == .orderedAscending
                        }
                        ForEach(Array(sorted.enumerated()), id: \.element) { index, category in
                            if index > 0 {
                                Divider().padding(.leading, 4)
                            }
                            Button {
                                viewModel.toggleCategory(category)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(category.iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(Color(hex: category.color))
                                        .frame(width: 28, height: 28)

                                    Text(category.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if viewModel.enabledCategories.contains(category) {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.Trakke.brand)
                                    }
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .accessibilityAddTraits(viewModel.enabledCategories.contains(category) ? .isSelected : [])
                        }
                    }

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "categories.title"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.Trakke.brand)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

}
