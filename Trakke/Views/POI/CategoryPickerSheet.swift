import SwiftUI

struct CategoryPickerSheet: View {
    @Bindable var viewModel: POIViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(POICategory.allCases) { category in
                    Button {
                        viewModel.toggleCategory(category)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.iconName)
                                .foregroundStyle(Color(hex: category.color))
                                .frame(width: 28, height: 28)

                            Text(category.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if viewModel.enabledCategories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "categories.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
