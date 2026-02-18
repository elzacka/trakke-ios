import SwiftUI
import CoreLocation

struct WaypointEditSheet: View {
    @Bindable var viewModel: WaypointViewModel
    var editingWaypoint: Waypoint?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var category: String = ""
    @State private var showSuggestions = false
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var categoryFieldFocused: Bool

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

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
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
            }
            .onAppear {
                if let wp = editingWaypoint {
                    name = wp.name
                    category = wp.category ?? ""
                }
                nameFieldFocused = true
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
            .submitLabel(.next)
            .onSubmit {
                categoryFieldFocused = true
            }
        }
    }

    // MARK: - Category Card

    private var categoryCard: some View {
        CardSection(String(localized: "waypoints.category")) {
            TextField(
                String(localized: "waypoints.categoryPlaceholder"),
                text: $category
            )
            .font(Font.Trakke.bodyRegular)
            .focused($categoryFieldFocused)
            .submitLabel(.done)
            .onChange(of: category) {
                showSuggestions = !category.isEmpty && !filteredSuggestions.isEmpty
            }
            .onChange(of: categoryFieldFocused) {
                if categoryFieldFocused && !category.isEmpty {
                    showSuggestions = !filteredSuggestions.isEmpty
                }
            }

            if showSuggestions {
                Divider().padding(.leading, .Trakke.dividerLeading)
                ForEach(filteredSuggestions, id: \.self) { suggestion in
                    Button {
                        category = suggestion
                        showSuggestions = false
                        categoryFieldFocused = false
                    } label: {
                        Text(suggestion)
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, .Trakke.xs)
                    }
                    Divider().padding(.leading, .Trakke.dividerLeading)
                }
            }
        }
    }

    // MARK: - Suggestions

    private var filteredSuggestions: [String] {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return viewModel.categories.filter {
            $0.lowercased().contains(trimmed) && $0.lowercased() != trimmed
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat: String? = trimmedCategory.isEmpty ? nil : trimmedCategory

        if let wp = editingWaypoint {
            viewModel.updateWaypoint(wp, name: trimmedName, category: cat)
        } else if let coordinate = viewModel.placingCoordinate {
            viewModel.addWaypoint(name: trimmedName, coordinate: coordinate, category: cat)
            viewModel.cancelPlacing()
        }

        dismiss()
    }
}
