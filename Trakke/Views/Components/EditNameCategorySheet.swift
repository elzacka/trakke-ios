import SwiftUI

/// Reusable edit sheet for renaming + categorising a Route, Activity, or other
/// named item. Replaces SwiftUI `.alert` with two TextFields, which generates
/// AutoLayout constraint conflicts (the system alert is only designed for one
/// input). A proper sheet also has more breathing room and supports category
/// autocomplete.
struct EditNameCategorySheet: View {
    let title: String
    let initialName: String
    let initialCategory: String
    /// Existing category strings used for live autocomplete suggestions.
    let categorySuggestions: [String]
    /// Placeholder shown in the name field (e.g. "Navn på ruten").
    let namePlaceholder: String
    let onSave: (_ name: String, _ category: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: String
    @State private var showSuggestions = false
    @FocusState private var nameFocused: Bool
    @FocusState private var categoryFocused: Bool

    init(
        title: String,
        initialName: String,
        initialCategory: String,
        categorySuggestions: [String],
        namePlaceholder: String,
        onSave: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.initialCategory = initialCategory
        self.categorySuggestions = categorySuggestions
        self.namePlaceholder = namePlaceholder
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _category = State(initialValue: initialCategory)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commitSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmedName, trimmedCategory)
        dismiss()
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.save")) {
                        commitSave()
                    }
                    .fontWeight(.medium)
                    .disabled(!canSave)
                }
                // Mirror the Save action in the keyboard toolbar so a user with
                // the keyboard up (often with gloves outdoors) can confirm without
                // reaching the navigation bar.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.save")) {
                        commitSave()
                    }
                    .fontWeight(.medium)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                nameFocused = true
            }
        }
    }

    private var nameCard: some View {
        CardSection(String(localized: "waypoints.name")) {
            TextField(namePlaceholder, text: $name)
                .font(Font.Trakke.bodyRegular)
                .focused($nameFocused)
                .submitLabel(.next)
                .onSubmit { categoryFocused = true }
        }
    }

    private var categoryCard: some View {
        CardSection(String(localized: "common.category")) {
            TextField(
                String(localized: "waypoints.categoryPlaceholder"),
                text: $category
            )
            .font(Font.Trakke.bodyRegular)
            .focused($categoryFocused)
            .submitLabel(.done)
            .onChange(of: category) {
                showSuggestions = !category.isEmpty && !filteredSuggestions.isEmpty
            }
            .onChange(of: categoryFocused) {
                if categoryFocused && !category.isEmpty {
                    showSuggestions = !filteredSuggestions.isEmpty
                }
            }

            if showSuggestions {
                Divider().padding(.leading, .Trakke.dividerLeading)
                ForEach(filteredSuggestions, id: \.self) { suggestion in
                    Button {
                        category = suggestion
                        showSuggestions = false
                        categoryFocused = false
                    } label: {
                        Text(suggestion)
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, .Trakke.xs)
                    }
                    .accessibilityHint(String(localized: "edit.category.suggestion.hint"))
                    Divider().padding(.leading, .Trakke.dividerLeading)
                }
            }
        }
    }

    private var filteredSuggestions: [String] {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return categorySuggestions.filter {
            $0.lowercased().contains(trimmed) && $0.lowercased() != trimmed
        }
    }
}
