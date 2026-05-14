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
        Group {
            if viewModel.routes.isEmpty {
                EmptyStateView(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    title: String(localized: "routes.empty.title"),
                    subtitle: String(localized: "routes.empty.subtitle"),
                    actionLabel: String(localized: "import.file"),
                    actionIcon: "square.and.arrow.up",
                    action: { showFileImporter = true }
                )
            } else {
                routeList
            }
        }
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(String(localized: "routes.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNewRoute?()
                    dismissFully()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "routes.new"))
            }
        }
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
                // Categorised groups first (alphabetical), then uncategorised under
                // "Lagrede ruter" so users without category usage see the original layout.
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

                VStack(spacing: .Trakke.sm) {
                    Button {
                        showFileImporter = true
                    } label: {
                        HStack(spacing: .Trakke.sm) {
                            if viewModel.isImporting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Color.Trakke.brand)
                                Text(String(localized: "import.inProgress"))
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text(String(localized: "import.file"))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkeSecondary)
                    .disabled(viewModel.isImporting)

                    if viewModel.routes.count >= 2 {
                        bulkVisibilityButton
                    }
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func routeGroup(title: String, category: String?, items: [Route]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryHeader(title: title, category: category, count: items.count)

            if expandedCategories.contains(title) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, route in
                        if index > 0 {
                            Divider().padding(.leading, .Trakke.dividerLeading)
                        }
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
                                viewModel.toggleVisibility(route)
                            } label: {
                                Label(
                                    route.isVisible
                                        ? String(localized: "routes.hideFromMap")
                                        : String(localized: "routes.showOnMap"),
                                    systemImage: route.isVisible ? "eye.slash" : "eye"
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
                    }
                }
                .padding(.horizontal, .Trakke.cardPadH)
                .padding(.vertical, .Trakke.cardPadV)
                .background(Color(.secondarySystemGroupedBackground))
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

            // Status pip only when hidden. The NavigationLink renders its own
            // disclosure chevron, so a manual chevron would duplicate it.
            if !route.isVisible {
                Image(systemName: "eye.slash")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
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
        HStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                    if expandedCategories.contains(title) {
                        expandedCategories.remove(title)
                    } else {
                        expandedCategories.insert(title)
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    Text(title.uppercased())
                        .font(Font.Trakke.sectionHeader)
                        .foregroundStyle(Color.Trakke.textTertiary)

                    Text(" (\(count))")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textTertiary)

                    Spacer()
                }
                .padding(.leading, .Trakke.xs)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(count)")
            .accessibilityAddTraits(expandedCategories.contains(title) ? .isSelected : [])

            Button {
                viewModel.setCategoryVisibility(category, visible: !allVisible)
            } label: {
                Image(systemName: allVisible ? "eye" : "eye.slash")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                allVisible
                    ? String(localized: "list.category.hideAll \(title)")
                    : String(localized: "list.category.showAll \(title)")
            )

            Button {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
                    if expandedCategories.contains(title) {
                        expandedCategories.remove(title)
                    } else {
                        expandedCategories.insert(title)
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .rotationEffect(expandedCategories.contains(title) ? .degrees(90) : .degrees(0))
                    .padding(.trailing, .Trakke.xs)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Bulk Visibility (footer)

    private var bulkVisibilityButton: some View {
        let anyVisible = viewModel.isAnyVisible
        return Button {
            viewModel.setAllVisible(!anyVisible)
        } label: {
            HStack(spacing: .Trakke.sm) {
                Image(systemName: anyVisible ? "eye.slash" : "eye")
                Text(
                    anyVisible
                        ? String(localized: "routes.hideAllOnMap")
                        : String(localized: "routes.showAllOnMap")
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.trakkeSecondary)
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
