import SwiftUI

struct RouteDetailSheet: View {
    @Bindable var viewModel: RouteViewModel
    let route: Route
    var onNavigate: ((Route) -> Void)?
    var isEmbedded = false
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: ShareableURL?
    @State private var showDeleteConfirmation = false
    @State private var showEditDialog = false

    var body: some View {
        if isEmbedded {
            content
        } else {
            NavigationStack {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: .Trakke.cardGap) {
                routeInfoCard
                elevationCard
                actionsCard

                Spacer(minLength: .Trakke.lg)
            }
            .padding(.horizontal, .Trakke.sheetHorizontal)
            .padding(.top, .Trakke.sheetTop)
        }
        .background(Color(.systemGroupedBackground))
        .tint(Color.Trakke.brand)
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditDialog = true
                } label: {
                    Label(String(localized: "common.edit"), systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEditDialog) {
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
    }

    // MARK: - Route Info

    private var routeInfoCard: some View {
        CardSection(String(localized: "route.info")) {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(route.name)
                    .font(Font.Trakke.bodyMedium)
                Text(viewModel.formattedDistance(route.distance))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
            }
            .padding(.vertical, .Trakke.xs)

            if let gain = route.elevationGain, gain > 0 {
                Divider().padding(.leading, .Trakke.dividerLeading)
                infoRow(
                    label: String(localized: "elevation.gain"),
                    icon: "arrow.up.right",
                    value: "\(Int(gain)) m"
                )
            }

            if let loss = route.elevationLoss, loss > 0 {
                Divider().padding(.leading, .Trakke.dividerLeading)
                infoRow(
                    label: String(localized: "elevation.loss"),
                    icon: "arrow.down.right",
                    value: "\(Int(loss)) m"
                )
            }

            Divider().padding(.leading, .Trakke.dividerLeading)
            infoRow(
                label: String(localized: "route.points"),
                icon: "mappin.and.ellipse",
                value: "\(route.coordinates.count)"
            )

            Divider().padding(.leading, .Trakke.dividerLeading)
            HStack {
                Label(
                    String(localized: "routes.visibleOnMap"),
                    systemImage: route.isVisible ? "eye" : "eye.slash"
                )
                .font(Font.Trakke.bodyRegular)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { route.isVisible },
                    set: { _ in viewModel.toggleVisibility(route) }
                ))
                .labelsHidden()
                .accessibilityLabel(String(localized: "routes.visibleOnMap"))
            }
            .padding(.vertical, .Trakke.xs)
        }
    }

    // MARK: - Elevation Profile

    private var elevationCard: some View {
        CardSection(String(localized: "elevation.profile")) {
            if viewModel.isLoadingElevation {
                HStack {
                    ProgressView()
                    Text(String(localized: "elevation.loading"))
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textTertiary)
                        .padding(.leading, .Trakke.sm)
                }
                .padding(.vertical, .Trakke.xs)
            } else if !viewModel.elevationProfile.isEmpty {
                ElevationProfileView(
                    points: viewModel.elevationProfile,
                    stats: viewModel.elevationStats
                )
                .padding(.vertical, .Trakke.xs)
            } else {
                Text(String(localized: "elevation.unavailable"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .padding(.vertical, .Trakke.xs)
            }
        }
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: .Trakke.sm) {
            if route.coordinates.count >= 2 {
                Button {
                    onNavigate?(route)
                } label: {
                    Label(String(localized: "navigation.start"), systemImage: "location.north.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.trakkePrimary)
            }

            Button {
                if let url = viewModel.exportGPX(for: route) {
                    shareURL = ShareableURL(url: url)
                }
            } label: {
                Label(String(localized: "export.share"), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.trakkeSecondary)

            Button {
                showDeleteConfirmation = true
            } label: {
                Label(String(localized: "common.delete"), systemImage: "trash")
            }
            .buttonStyle(.trakkeDanger)
            .confirmationDialog(
                String(localized: "routes.delete.title"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "routes.delete.confirm"), role: .destructive) {
                    viewModel.deleteRoute(route)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, icon: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(Font.Trakke.bodyRegular)
            Spacer()
            Text(value)
                .font(Font.Trakke.bodyRegular.monospacedDigit())
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.vertical, .Trakke.xs)
    }

}
