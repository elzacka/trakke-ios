import SwiftUI
import CoreLocation

struct WaypointEditSheet: View {
    @Bindable var viewModel: WaypointViewModel
    var editingWaypoint: Waypoint?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var category: String = ""
    @State private var details: String = ""
    @State private var isAddingNewCategory = false
    @State private var newCategoryName: String = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var newCategoryFieldFocused: Bool

    private var isEditing: Bool { editingWaypoint != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    nameCard
                    categoryCard
                    detailsCard

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color.Trakke.background)
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: isEditing ? "common.edit" : "waypoints.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        if !isEditing {
                            viewModel.cancelPlacing()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.save")) {
                        save()
                    }
                    .fontWeight(.medium)
                    .disabled(!canSave)
                }
                // Mirror the Save action in the keyboard toolbar so a user with
                // the keyboard up (often with gloves outdoors) can confirm
                // without reaching the navigation bar.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.save")) {
                        save()
                    }
                    .fontWeight(.medium)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let wp = editingWaypoint {
                    name = wp.name
                    category = wp.category ?? ""
                    details = wp.details ?? ""
                } else {
                    // Autofocus the name field only when creating a new place —
                    // editing an existing one should not pop the keyboard and
                    // hide the category list.
                    nameFieldFocused = true
                }
            }
        }
    }

    // MARK: - Name Card

    private var nameCard: some View {
        CardSection(String(localized: "waypoints.name")) {
            TextField(
                String(localized: "waypoints.namePlaceholder"),
                text: $name
            )
            .font(Font.Trakke.bodyRegular)
            .focused($nameFieldFocused)
            .submitLabel(.done)
        }
    }

    // MARK: - Category Card

    private var categoryCard: some View {
        CardSection(String(localized: "waypoints.category")) {
            categoryOptionRow(nil)

            ForEach(viewModel.categories, id: \.self) { cat in
                Divider().padding(.leading, .Trakke.dividerLeading)
                categoryOptionRow(cat)
            }

            // Ny kategori som er valgt men ennå ikke lagret til DB
            if !isAddingNewCategory && !category.isEmpty && !viewModel.categories.contains(category) {
                Divider().padding(.leading, .Trakke.dividerLeading)
                categoryOptionRow(category)
            }

            Divider().padding(.leading, .Trakke.dividerLeading)

            if isAddingNewCategory {
                HStack(spacing: .Trakke.sm) {
                    TextField(
                        String(localized: "waypoints.categoryNamePlaceholder"),
                        text: $newCategoryName
                    )
                    .font(Font.Trakke.bodyRegular)
                    .focused($newCategoryFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { confirmNewCategory() }

                    Button(String(localized: "common.done")) {
                        confirmNewCategory()
                    }
                    .font(Font.Trakke.bodyRegular)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, .Trakke.rowVertical)
                .frame(minHeight: .Trakke.touchMin)
            } else {
                Button {
                    isAddingNewCategory = true
                    newCategoryFieldFocused = true
                } label: {
                    Label(
                        String(localized: "waypoints.addNewCategory"),
                        systemImage: "plus"
                    )
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.brand)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, .Trakke.rowVertical)
                    .frame(minHeight: .Trakke.touchMin)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categoryOptionRow(_ cat: String?) -> some View {
        let label = cat ?? String(localized: "waypoints.noCategory")
        let value = cat ?? ""
        let isSelected = category == value

        return Button {
            category = value
            isAddingNewCategory = false
        } label: {
            HStack(spacing: .Trakke.md) {
                Text(label)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(Font.Trakke.bodyRegular.weight(.semibold))
                        .foregroundStyle(Color.Trakke.brand)
                } else {
                    Color.clear
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.vertical, .Trakke.rowVertical)
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func confirmNewCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // If a category with this name already exists (case-insensitive), select
        // it instead of creating a pending duplicate — prevents "fjell" and
        // "Fjell" coexisting.
        if let existing = viewModel.categories.first(where: {
            $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            category = existing
        } else {
            category = trimmed
        }
        isAddingNewCategory = false
        newCategoryName = ""
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        CardSection(String(localized: "waypoints.details")) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $details)
                    .font(Font.Trakke.bodyRegular)
                    .frame(minHeight: 80, maxHeight: 200)
                    .scrollContentBackground(.hidden)

                if details.isEmpty {
                    Text(String(localized: "waypoints.detailsPlaceholder"))
                        .font(Font.Trakke.bodyRegular)
                        .foregroundStyle(Color.Trakke.textSoft)
                        .allowsHitTesting(false)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        if isAddingNewCategory {
            confirmNewCategory()
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat: String? = trimmedCategory.isEmpty ? nil : trimmedCategory

        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let det: String? = trimmedDetails.isEmpty ? nil : trimmedDetails

        if let wp = editingWaypoint {
            viewModel.updateWaypoint(wp, name: trimmedName, category: cat, details: det)
        } else if let coordinate = viewModel.placingCoordinate {
            viewModel.addWaypoint(name: trimmedName, coordinate: coordinate, category: cat, details: det)
            viewModel.cancelPlacing()
        }

        dismiss()
    }
}
