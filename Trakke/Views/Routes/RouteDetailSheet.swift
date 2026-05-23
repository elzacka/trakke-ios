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
        VStack(spacing: 0) {
            if !isEmbedded {
                TrakkeSheetHeader(title: route.name)
            }

            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    routeInfoCard
                    elevationCard
                    actionsCard

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, isEmbedded ? .Trakke.sheetTop : .Trakke.sm)
                .padding(.bottom, .Trakke.xxl)
            }
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .modifier(EmbeddedNavTitleModifier(isEmbedded: isEmbedded, title: route.name))
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
                    .foregroundStyle(Color.Trakke.textSoft)
            }
            .padding(.vertical, .Trakke.rowVertical)

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
                .toggleStyle(.trakke)
                .accessibilityLabel(String(localized: "routes.visibleOnMap"))
            }
            .padding(.vertical, .Trakke.rowVertical)
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
                        .foregroundStyle(Color.Trakke.textSoft)
                        .padding(.leading, .Trakke.sm)
                }
                .padding(.vertical, .Trakke.rowVertical)
            } else if !viewModel.elevationProfile.isEmpty {
                ElevationProfileView(
                    points: viewModel.elevationProfile,
                    stats: viewModel.elevationStats
                )
                .padding(.vertical, .Trakke.rowVertical)
            } else {
                Text(String(localized: "elevation.unavailable"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .padding(.vertical, .Trakke.rowVertical)
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
                showEditDialog = true
            } label: {
                Label(String(localized: "common.edit"), systemImage: "pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.trakkeSecondary)

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
            .trakkeDialog(
                isPresented: $showDeleteConfirmation,
                title: String(localized: "routes.delete.title"),
                primary: .destructive(String(localized: "common.yes")) {
                    viewModel.deleteRoute(route)
                    dismiss()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
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
                .foregroundStyle(Color.Trakke.textSoft)
        }
        .padding(.vertical, .Trakke.rowVertical)
    }

}

/// Setter navigationTitle bare når viewet er pushet (isEmbedded), så parent
/// NavigationStack viser tittel og back-knapp i toolbaren. Når viewet
/// presenteres som top-level sheet, viser TrakkeSheetHeader tittelen i stedet.
private struct EmbeddedNavTitleModifier: ViewModifier {
    let isEmbedded: Bool
    let title: String

    func body(content: Content) -> some View {
        if isEmbedded {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}
