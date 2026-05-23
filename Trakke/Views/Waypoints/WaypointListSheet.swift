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
        Group {
                if viewModel.waypoints.isEmpty {
                    EmptyStateView(
                        title: String(localized: "waypoints.empty.title"),
                        subtitle: String(localized: "waypoints.empty.subtitle"),
                        actionLabel: String(localized: "import.file"),
                        actionIcon: "square.and.arrow.up",
                        action: { showFileImporter = true }
                    )
                } else {
                    waypointList
                }
            }
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

                // Bulk-synlighet beholdes for Steder: punktene kan vises på
                // kartet uten å overstyre topo-lesningen slik mange ruter/turer
                // ville gjort.
                if viewModel.waypoints.count >= 2 {
                    bulkVisibilityButton
                }

                // Sekundærhandlinger — importer, eksporter, slett.
                // Ikon-bar høyrejustert: signaliserer at dette er
                // utility-handlinger, ikke primær-flyten.
                secondaryActionBar

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
        VStack(alignment: .leading, spacing: 0) {
            categoryHeader(title: title, category: category, count: items.count)

            if expandedCategories.contains(title) {
                VStack(spacing: 0) {
                    ForEach(items) { waypoint in
                        if items.first?.id != waypoint.id {
                            Divider()
                        }
                        HStack(spacing: 0) {
                            NavigationLink(value: waypoint) {
                                waypointRow(waypoint)
                                    // Make the whole row hit-testable so long press
                                    // works on padding / Spacer area, not just the
                                    // label text.
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
                .padding(.horizontal, .Trakke.cardPadH)
                .padding(.vertical, .Trakke.cardPadV)
                .background(Color.Trakke.surface)
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
                .padding(.top, .Trakke.sm)
            }
        }
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
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, .Trakke.rowVertical)
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

    /// Header with three discrete tap targets: collapse on title, eye toggle
    /// for the whole category, chevron also collapses (accessibility-hidden
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
                Group {
                    if allVisible {
                        Image(systemName: "checkmark")
                            .font(Font.Trakke.bodyMedium)
                            .foregroundStyle(Color.Trakke.brand)
                    } else {
                        Color.clear
                    }
                }
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

    // MARK: - Secondary action bar (importer / eksporter / slett)

    private var secondaryActionBar: some View {
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
                        ? String(localized: "waypoints.hideAllOnMap")
                        : String(localized: "waypoints.showAllOnMap")
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.trakkeSecondary)
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
