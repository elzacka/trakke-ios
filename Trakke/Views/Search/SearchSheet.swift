import SwiftUI

struct SearchSheet: View {
    @Bindable var viewModel: SearchViewModel
    let onResultSelected: (SearchResult) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                resultsList
            }
            .navigationTitle(String(localized: "search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(String(localized: "search.placeholder"), text: Binding(
                get: { viewModel.query },
                set: { viewModel.updateQuery($0) }
            ))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "search.clear"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var resultsList: some View {
        Group {
            if viewModel.isSearching {
                VStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.results.isEmpty && !viewModel.query.isEmpty && viewModel.query.count >= 2 {
                VStack {
                    Spacer()
                    Text(String(localized: "search.noResults"))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(viewModel.results) { result in
                    SearchResultRow(result: result)
                        .onTapGesture {
                            viewModel.selectResult(result)
                            onResultSelected(result)
                            dismiss()
                        }
                }
                .listStyle(.plain)
            }
        }
    }
}
