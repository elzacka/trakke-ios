import SwiftUI
import UniformTypeIdentifiers

struct WaypointListSheet: View {
    @Bindable var viewModel: WaypointViewModel
    var onWaypointSelected: ((Waypoint) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showFileImporter = false
    @State private var showShareSheet = false
    @State private var gpxURL: URL?
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.waypoints.isEmpty {
                    EmptyStateView(
                        icon: "mappin",
                        title: String(localized: "waypoints.empty.title"),
                        subtitle: String(localized: "waypoints.empty.subtitle")
                    )
                } else {
                    waypointList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "waypoints.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.gpx],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    viewModel.importGPX(from: url)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = gpxURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.importMessage != nil {
                    importBanner
                }
            }
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

                // Actions: Export first, Import second
                VStack(spacing: .Trakke.sm) {
                    Button {
                        gpxURL = viewModel.exportAllGPX()
                        if gpxURL != nil {
                            showShareSheet = true
                        }
                    } label: {
                        Label(String(localized: "waypoints.exportAll"), systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkeSecondary)

                    Button {
                        showFileImporter = true
                    } label: {
                        Label(String(localized: "waypoints.importGPX"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.trakkeSecondary)
                }

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
    }

    // MARK: - Collapsible Category

    private func collapsibleCategory(title: String, category: String?, items: [Waypoint]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedCategories.contains(title) {
                        expandedCategories.remove(title)
                    } else {
                        expandedCategories.insert(title)
                    }
                }
            } label: {
                HStack {
                    Text(title.uppercased())
                        .font(Font.Trakke.sectionHeader)
                        .foregroundStyle(Color.Trakke.textSoft)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.Trakke.textSoft)
                        .rotationEffect(expandedCategories.contains(title) ? .degrees(90) : .degrees(0))
                }
                .padding(.horizontal, .Trakke.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedCategories.contains(title) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, waypoint in
                        if index > 0 {
                            Divider()
                        }
                        Button {
                            onWaypointSelected?(waypoint)
                            dismiss()
                        } label: {
                            waypointRow(waypoint)
                        }
                        .contextMenu {
                            contextMenuItems(for: waypoint)
                        }
                    }

                    Divider()

                    categoryVisibilityToggle(category: category, items: items)
                }
                .padding(.horizontal, .Trakke.cardPadH)
                .padding(.vertical, .Trakke.cardPadV)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: .TrakkeRadius.lg))
                .padding(.top, .Trakke.sm)
            }
        }
    }

    // MARK: - Row

    private func waypointRow(_ waypoint: Waypoint) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(waypoint.name)
                    .font(Font.Trakke.bodyMedium)
                    .foregroundStyle(Color.Trakke.brand)

                if let elevation = waypoint.elevation {
                    Text("\(Int(elevation)) moh.")
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
            }

            Spacer()

            Image(systemName: waypoint.isVisible ? "chevron.right" : "eye.slash")
                .font(.caption2)
                .foregroundStyle(Color.Trakke.textSoft)
        }
        .padding(.vertical, .Trakke.rowVertical)
        .opacity(waypoint.isVisible ? 1 : 0.45)
    }

    // MARK: - Category Visibility Toggle

    private func categoryVisibilityToggle(category: String?, items: [Waypoint]) -> some View {
        let allVisible = viewModel.isCategoryAllVisible(category)
        return Toggle(isOn: Binding(
            get: { allVisible },
            set: { viewModel.setCategoryVisibility(category, visible: $0) }
        )) {
            Text(String(localized: "waypoints.showAllOnMap"))
                .font(Font.Trakke.bodyRegular)
        }
        .tint(Color.Trakke.brand)
        .padding(.vertical, .Trakke.rowVertical)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for waypoint: Waypoint) -> some View {
        Button {
            viewModel.toggleVisibility(waypoint)
        } label: {
            Label(
                waypoint.isVisible
                    ? String(localized: "waypoints.hideFromMap")
                    : String(localized: "waypoints.showOnMap"),
                systemImage: waypoint.isVisible ? "eye.slash" : "eye"
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
            .foregroundStyle(.white)
            .padding(.horizontal, .Trakke.lg)
            .padding(.vertical, .Trakke.sm)
            .background(Color.Trakke.brand)
            .clipShape(Capsule())
            .padding(.bottom, .Trakke.lg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation {
                    viewModel.importMessage = nil
                }
            }
    }
}
