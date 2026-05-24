import SwiftUI
import UniformTypeIdentifiers

struct RouteListSheet: View {
    @Bindable var viewModel: RouteViewModel
    var onRouteSelected: ((Route) -> Void)?
    var onNewRoute: (() -> Void)?
    var isEmbedded = false
    var dismissSheet: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showFileImporter = false
    @State private var editingRoute: Route?
    @State private var shareURL: ShareableURL?
    @State private var showDeleteAllConfirmation = false
    // Collapsed by default — modern iOS pattern (Files, Notes, Mail use the
    // same disclosure style). Set persisted only in-memory; user expands what
    // they need each visit.
    @State private var expandedCategories: Set<String> = []

    private func dismissFully() {
        if let dismissSheet { dismissSheet() } else { dismiss() }
    }

    var body: some View {
        if isEmbedded {
            routeContent
        } else {
            NavigationStack {
                routeContent
            }
        }
    }

    private var routeContent: some View {
        routeList
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "routes.title"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.gpx, .geoJSON],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await viewModel.importFileAsync(from: url) }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.importMessage != nil {
                importBanner
            }
        }
        .sheet(item: $editingRoute) { route in
            EditNameCategorySheet(
                title: String(localized: "common.edit"),
                initialName: route.name,
                initialCategory: route.category ?? "",
                categorySuggestions: viewModel.categories,
                namePlaceholder: String(localized: "routes.namePlaceholder")
            ) { newName, newCategory in
                viewModel.edit(route, name: newName, category: newCategory)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
        }
        .navigationDestination(for: Route.self) { route in
            RouteDetailSheet(
                viewModel: viewModel,
                route: route,
                onNavigate: { route in
                    onRouteSelected?(route)
                    dismissFully()
                },
                isEmbedded: true
            )
        }
    }

    private var routeList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                // Handlingsbar øverst — fire ikoner: tegne ny rute, importere,
                // eksportere, slette alle. Høyrejustert som "verktøy"-rad.
                actionBar

                if viewModel.routes.isEmpty {
                    EmptyStateView(
                        title: String(localized: "routes.empty.title"),
                        subtitle: String(localized: "routes.empty.subtitle"),
                        alignment: .leading
                    )
                    .padding(.top, .Trakke.xxl)
                } else {
                    ForEach(viewModel.categories, id: \.self) { category in
                        routeGroup(title: category, category: category, items: viewModel.routes(for: category))
                    }

                    if !viewModel.uncategorizedRoutes.isEmpty {
                        routeGroup(
                            title: viewModel.categories.isEmpty
                                ? String(localized: "routes.saved")
                                : String(localized: "routes.uncategorized"),
                            category: nil,
                            items: viewModel.uncategorizedRoutes
                        )
                    }
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color.Trakke.background)
    }

    private func routeGroup(title: String, category: String?, items: [Route]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryHeader(title: title, category: category, count: items.count)

            if expandedCategories.contains(title) {
                VStack(spacing: 0) {
                    ForEach(items) { route in
                        if items.first?.id != route.id {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                        }
                        HStack(spacing: 0) {
                            NavigationLink(value: route) {
                                routeRow(route)
                                    // Make the whole row hit-testable so long press
                                    // works on padding / Spacer area, not just the
                                    // label text.
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                // Solo first — most powerful single-purpose action
                                // for the "show only this" planning flow.
                                Button {
                                    viewModel.showOnly(route)
                                    UIAccessibility.post(
                                        notification: .announcement,
                                        argument: String(localized: "list.showOnlyThis.announce \(route.name)")
                                    )
                                } label: {
                                    Label(
                                        String(localized: "routes.showOnlyThis"),
                                        systemImage: "eye.circle"
                                    )
                                }

                                Button {
                                    editingRoute = route
                                } label: {
                                    Label(String(localized: "common.edit"), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    viewModel.deleteRoute(route)
                                } label: {
                                    Label(String(localized: "common.delete"), systemImage: "trash")
                                }
                            }

                            VisibilityToggleButton(
                                isVisible: route.isVisible,
                                accessibilityLabel: route.isVisible
                                    ? String(localized: "routes.hideFromMap")
                                    : String(localized: "routes.showOnMap")
                            ) {
                                viewModel.toggleVisibility(route)
                            }
                        }
                    }
                }
                .padding(.horizontal, .Trakke.cardPadH)
                .padding(.vertical, .Trakke.cardPadV)
                .background(Color.Trakke.surface)
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
                .padding(.top, .Trakke.sm)
            }
        }
    }

    private func routeRow(_ route: Route) -> some View {
        HStack(spacing: .Trakke.md) {
            Circle()
                .fill(Color(hex: route.color ?? "#E07000"))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(route.name)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)

                // Én sentral verdi i listen: distanse. Høydemeter lever i
                // RouteDetailSheet.
                Text(viewModel.formattedDistance(route.distance))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, .Trakke.rowVertical)
        .opacity(route.isVisible ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(routeAccessibilityLabel(route))
    }

    private func routeAccessibilityLabel(_ route: Route) -> String {
        var parts = [route.name, viewModel.formattedDistance(route.distance)]
        if let gain = route.elevationGain, gain > 0 {
            parts.append("+\(Int(gain)) m")
        }
        if !route.isVisible {
            parts.append(String(localized: "routes.hiddenFromMap"))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Category Header

    /// Header with three discrete tap targets: collapse on title, eye toggle
    /// for the whole category, chevron also collapses (decorative for VoiceOver
    /// since the title button already announces collapsed/expanded).
    @ViewBuilder
    private func categoryHeader(title: String, category: String?, count: Int) -> some View {
        let allVisible = viewModel.isCategoryAllVisible(category)
        let isExpanded = expandedCategories.contains(title)
        // Horisontal padding cardPadH gir hake-knappen samme x-posisjon som
        // per-rad hake-knappen i kortet under — de flukter vertikalt.
        HStack(spacing: 0) {
            // Tittel-knapp: chevron + tittel + telling som ett tap-areal.
            // Chevron-rotasjon viser åpen/lukket tilstand.
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedCategories.remove(title)
                    } else {
                        expandedCategories.insert(title)
                    }
                }
            } label: {
                HStack(spacing: .Trakke.xs) {
                    Image(systemName: "chevron.right")
                        .font(Font.Trakke.captionSoft.weight(.semibold))
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .rotationEffect(isExpanded ? .degrees(90) : .degrees(0))

                    Text(title.uppercased())
                        .font(Font.Trakke.sectionHeader)
                        .foregroundStyle(Color.Trakke.textTertiary)

                    Text(" (\(count))")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)

                    Spacer()
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(count)")
            .accessibilityAddTraits(isExpanded ? .isSelected : [])

            // Hake helt til høyre — toggler synlighet for hele kategorien.
            // Samme komponent og x-posisjon som per-rad VisibilityToggleButton.
            Button {
                viewModel.setCategoryVisibility(category, visible: !allVisible)
            } label: {
                Group {
                    if allVisible {
                        Image(systemName: "checkmark")
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.brand)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: .Trakke.touchMin, height: .Trakke.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                allVisible
                    ? String(localized: "list.category.hideAll \(title)")
                    : String(localized: "list.category.showAll \(title)")
            )
        }
        .padding(.horizontal, .Trakke.cardPadH)
    }

    // MARK: - Action bar (tegne / importer / eksporter / slett)

    private var actionBar: some View {
        HStack(spacing: .Trakke.sm) {
            Spacer()

            TrakkeIconButton(
                systemImage: "plus",
                accessibilityLabel: String(localized: "routes.draw"),
                action: {
                    onNewRoute?()
                    dismissFully()
                }
            )

            TrakkeIconButton(
                systemImage: "square.and.arrow.up",
                isLoading: viewModel.isImporting,
                accessibilityLabel: viewModel.isImporting
                    ? String(localized: "import.inProgress")
                    : String(localized: "import.file"),
                action: { showFileImporter = true }
            )

            TrakkeIconButton(
                systemImage: "square.and.arrow.down",
                isEnabled: !viewModel.routes.isEmpty,
                accessibilityLabel: String(localized: "import.exportAll"),
                action: {
                    if let url = viewModel.exportAllGPX() {
                        shareURL = ShareableURL(url: url)
                    }
                }
            )

            TrakkeIconButton(
                systemImage: "trash",
                role: .destructive,
                isEnabled: !viewModel.routes.isEmpty,
                accessibilityLabel: String(localized: "routes.deleteAll"),
                action: { showDeleteAllConfirmation = true }
            )
            .trakkeDialog(
                isPresented: $showDeleteAllConfirmation,
                title: String(localized: "routes.deleteAll.title"),
                message: String(localized: "routes.deleteAll.message"),
                primary: .destructive(String(localized: "common.yes")) {
                    viewModel.deleteAllRoutes()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
        }
    }

    // MARK: - Import Banner

    private var importBanner: some View {
        Text(viewModel.importMessage ?? "")
            .font(Font.Trakke.caption)
            .foregroundStyle(Color.Trakke.textInverse)
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(Color.Trakke.brand)
            .clipShape(Capsule())
            .padding(.bottom, .Trakke.lg)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(reduceMotion ? nil : .default) {
                    viewModel.importMessage = nil
                }
            }
    }
}
