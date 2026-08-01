import SwiftUI

/// Hjem-fanen – første sheet som åpnes når brukeren trykker FAB.
/// Inneholder søkefelt øverst (live søk mot Geonorge) og collapsed
/// kategori-hierarki under. Kategoriene skjules mens brukeren søker.
struct HomeTabContent: View {
    @Bindable var poiViewModel: POIViewModel
    @Bindable var searchViewModel: SearchViewModel
    var onResultSelected: (SearchResult) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TrakkeSheetHeader(title: String(localized: "appTab.home"))
                .onTapGesture { hideKeyboard() }

            ScrollView {
                VStack(spacing: .Trakke.md) {
                    TrakkeSearchField(
                        text: $searchViewModel.query,
                        placeholder: String(localized: "search.placeholder"),
                        rotatingPrefix: String(localized: "search.placeholder.prefix"),
                        rotatingWords: [
                            String(localized: "search.placeholder.word.place"),
                            String(localized: "search.placeholder.word.address"),
                            String(localized: "search.placeholder.word.coordinate")
                        ]
                    )
                    .onChange(of: searchViewModel.query) { _, newValue in
                        searchViewModel.updateQuery(newValue)
                    }

                    if isSearchActive {
                        searchResultsSection
                    } else {
                        CategoryHierarchyView(poiViewModel: poiViewModel)
                            // simultaneous: radene virker som før, men et trykk
                            // utenfor tastaturet lukker det også – ellers må
                            // brukeren forlate hele visningen for å se
                            // BottomNavBar igjen.
                            .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
                    }
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.lg)
                .padding(.bottom, .Trakke.xxl + 60)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.Trakke.background)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    private var isSearchActive: Bool {
        !searchViewModel.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if searchViewModel.isSearching {
            HStack {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.Trakke.brand)
                Text(String(localized: "search.searching"))
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .Trakke.lg)
        } else if let error = searchViewModel.error {
            Text(error)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .Trakke.lg)
        } else if searchViewModel.results.isEmpty
                    && searchViewModel.query.trimmingCharacters(in: .whitespaces).count >= 2 {
            Text(String(localized: "search.noResults"))
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .Trakke.lg)
        } else {
            LazyVStack(spacing: .Trakke.xs) {
                ForEach(searchViewModel.results) { result in
                    Button {
                        onResultSelected(result)
                    } label: {
                        SearchResultRow(result: result)
                            .padding(.horizontal, .Trakke.cardPadH)
                            .padding(.vertical, .Trakke.sm)
                            .frame(minHeight: .Trakke.touchMin)
                            .background(Color.Trakke.surface)
                            .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
