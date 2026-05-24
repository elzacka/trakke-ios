import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct WaypointListSheet: View {
    @Bindable var viewModel: WaypointViewModel
    var onWaypointSelected: ((Waypoint) -> Void)?
    var onWaypointEdit: ((Waypoint) -> Void)?
    var onWaypointNavigate: ((CLLocationCoordinate2D) -> Void)?
    var isEmbedded = false
    var dismissSheet: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showFileImporter = false
    @State private var shareURL: ShareableURL?
    @State private var expandedCategories: Set<String> = []
    @State private var showDeleteAllConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func dismissFully() {
        if let dismissSheet { dismissSheet() } else { dismiss() }
    }

    var body: some View {
        if isEmbedded {
            waypointContent
        } else {
            NavigationStack {
                waypointContent
            }
        }
    }

    private var waypointContent: some View {
        waypointList
            .tint(Color.Trakke.brand)
            .background(Color.Trakke.background)
            .navigationTitle(String(localized: "waypoints.title"))
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
            .sheet(item: $shareURL) { item in
                ShareSheet(activityItems: [item.url])
            }
            .overlay(alignment: .bottom) {
                if viewModel.importMessage != nil {
                    importBanner
                }
            }
            .navigationDestination(for: Waypoint.self) { waypoint in
                WaypointDetailSheet(
                    viewModel: viewModel,
                    waypoint: waypoint,
                    // Ikke dismiss her — onEdit/onNavigate setter
                    // sheets.active til en ny verdi, og SwiftUIs
                    // .sheet(item:) tar seg av overgangen automatisk.
                    // Manuell dismiss ville sette sheets.active = nil og
                    // kansellere den nye sheeten.
                    onEdit: { wp in
                        onWaypointEdit?(wp)
                    },
                    onNavigate: { coordinate in
                        onWaypointNavigate?(coordinate)
                    },
                    isEmbedded: true
                )
            }
    }

    // MARK: - Waypoint List

    private var waypointList: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                // Handlingsbar øverst — tre ikoner: importere, eksportere,
                // slette alle. Tilpasset versjon uten pluss-knapp siden
                // "legge til sted" gjøres med langt trykk på kartet.
                // Alltid synlig — også i tom tilstand — for konsistens med
                // Ruter og Turer.
                actionBar

                if viewModel.waypoints.isEmpty {
                    EmptyStateView(
                        title: String(localized: "waypoints.empty.title"),
                        subtitle: String(localized: "waypoints.empty.subtitle"),
                        alignment: .leading
                    )
                    .padding(.top, .Trakke.xxl)
                } else {
                    ForEach(viewModel.categories, id: \.self) { category in
                        collapsibleCategory(
                            title: category,
                            category: category,
                            items: viewModel.waypoints(for: category)
                        )
                    }

                    if !viewModel.uncategorizedWaypoints.isEmpty {
                        collapsibleCategory(
                            title: String(localized: "waypoints.uncategorized"),
                            category: nil,
                            items: viewModel.uncategorizedWaypoints
                        )
                    }
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
    }

    // MARK: - Collapsible Category

    private func collapsibleCategory(title: String, category: String?, items: [Waypoint]) -> some View {
        VStack(spacing: 0) {
            categoryHeader(title: title, count: items.count)

            if expandedCategories.contains(title) {
                Divider().padding(.leading, .Trakke.dividerLeading)

                ForEach(items) { waypoint in
                    if items.first?.id != waypoint.id {
                        Divider().padding(.leading, .Trakke.dividerLeading)
                    }
                    HStack(spacing: 0) {
                        NavigationLink(value: waypoint) {
                            waypointRow(waypoint)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            contextMenuItems(for: waypoint)
                        }

                        VisibilityToggleButton(
                            isVisible: waypoint.isVisible,
                            accessibilityLabel: waypoint.isVisible
                                ? String(localized: "waypoints.hideFromMap")
                                : String(localized: "waypoints.showOnMap")
                        ) {
                            viewModel.toggleVisibility(waypoint)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, .Trakke.cardPadH)
        .background(Color.Trakke.surface)
        .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
    }

    // MARK: - Row

    private func waypointRow(_ waypoint: Waypoint) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(waypoint.name)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.text)

                if let elevation = waypoint.elevation {
                    Text("\(Int(elevation)) moh.")
                        .font(Font.Trakke.captionSoft)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .frame(minHeight: .Trakke.touchMin)
        .opacity(waypoint.isVisible ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(waypointAccessibilityLabel(waypoint))
    }

    private func waypointAccessibilityLabel(_ waypoint: Waypoint) -> String {
        var parts = [waypoint.name]
        if let elevation = waypoint.elevation {
            parts.append("\(Int(elevation)) moh.")
        }
        if !waypoint.isVisible {
            parts.append(String(localized: "waypoints.hiddenFromMap"))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Category Header

    /// Kategori-header speiler ExpandableSection-stilen (Brukerveiledning,
    /// Personvernerklæring): plain tittel-tekst, chevron-down til høyre
    /// som roterer ved ekspandering, antall-tekst etter tittel. Per-
    /// kategori-synlighet-bryteren er fjernet — brukerne kan toggle per
    /// rad via VisibilityToggleButton.
    private func categoryHeader(title: String, count: Int) -> some View {
        let isExpanded = expandedCategories.contains(title)
        return Button {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedCategories.remove(title)
                } else {
                    expandedCategories.insert(title)
                }
            }
        } label: {
            HStack(spacing: .Trakke.md) {
                Text(title)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.text)

                Text("(\(count))")
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textSoft)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(Font.Trakke.captionSoft.weight(.semibold))
                    .foregroundStyle(Color.Trakke.textSoft)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, 12)
            .frame(minHeight: .Trakke.touchMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint(isExpanded
            ? String(localized: "accessibility.tapToCollapse")
            : String(localized: "accessibility.tapToExpand"))
    }

    // MARK: - Action bar (importer / eksporter / slett)
    //
    // Tilpasset versjon — har ingen pluss-knapp som Ruter og Turer fordi
    // "legge til sted" gjøres med langt trykk på kartet, ikke fra denne
    // visningen.

    private var actionBar: some View {
        HStack(spacing: .Trakke.sm) {
            Spacer()

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
                isEnabled: !viewModel.waypoints.isEmpty,
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
                isEnabled: !viewModel.waypoints.isEmpty,
                accessibilityLabel: String(localized: "waypoints.deleteAll"),
                action: { showDeleteAllConfirmation = true }
            )
            .trakkeDialog(
                isPresented: $showDeleteAllConfirmation,
                title: String(localized: "waypoints.deleteAll.title"),
                message: String(localized: "waypoints.deleteAll.message"),
                primary: .destructive(String(localized: "common.yes")) {
                    viewModel.deleteAllWaypoints()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for waypoint: Waypoint) -> some View {
        Button {
            viewModel.showOnly(waypoint)
            UIAccessibility.post(
                notification: .announcement,
                argument: String(localized: "list.showOnlyThis.announce \(waypoint.name)")
            )
        } label: {
            Label(
                String(localized: "waypoints.showOnlyThis"),
                systemImage: "eye.circle"
            )
        }

        Button(role: .destructive) {
            viewModel.deleteWaypoint(waypoint)
        } label: {
            Label(String(localized: "common.delete"), systemImage: "trash")
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
