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
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(String(localized: "search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                .foregroundStyle(Color.Trakke.textSoft)

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
                        .foregroundStyle(Color.Trakke.brand)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(String(localized: "search.clear"))
            }
        }
        .padding(.horizontal, .Trakke.md)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: .TrakkeRadius.lg)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, .Trakke.cardPadH)
        .padding(.vertical, .Trakke.sm)
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
            } else if let error = viewModel.error {
                VStack {
                    Spacer()
                    Text(error)
                        .foregroundStyle(Color.Trakke.textSoft)
                    Spacer()
                }
            } else if viewModel.results.isEmpty && !viewModel.query.isEmpty && viewModel.query.count >= 2 {
                VStack {
                    Spacer()
                    Text(String(localized: "search.noResults"))
                        .foregroundStyle(Color.Trakke.textSoft)
                    Spacer()
                }
            } else {
                List(viewModel.results) { result in
                    SearchResultRow(result: result)
                        .listRowBackground(Color(.systemGroupedBackground))
                        .onTapGesture {
                            viewModel.selectResult(result)
                            onResultSelected(result)
                            dismiss()
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
