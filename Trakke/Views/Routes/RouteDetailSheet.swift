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
            // Pushet visning får appens tilbakeknapp; top-level sheet har
            // ingen vei tilbake og viser bare tittelen.
            TrakkeSheetHeader(title: route.name, onBack: backAction)

            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    actionsCard
                    routeInfoCard
                    elevationCard

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sm)
                .padding(.bottom, .Trakke.xxl)
            }
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .toolbar(.hidden, for: .navigationBar)
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
    //
    // Høyrejustert ikon-bar – samme stil som Naviger-list-fanene. Posisjon
    // i HStack indikerer hierarki: primær-handling (naviger) først,
    // destruktiv (slett) sist.

    private var actionsCard: some View {
        HStack(spacing: .Trakke.sm) {
            Spacer()

            if route.coordinates.count >= 2 {
                TrakkeIconButton(
                    systemImage: "location.north.fill",
                    accessibilityLabel: String(localized: "navigation.start"),
                    action: { onNavigate?(route) }
                )
            }

            TrakkeIconButton(
                systemImage: "pencil",
                accessibilityLabel: String(localized: "common.edit"),
                action: { showEditDialog = true }
            )

            TrakkeIconButton(
                systemImage: "square.and.arrow.down",
                accessibilityLabel: String(localized: "export.share"),
                action: {
                    if let url = viewModel.exportGPX(for: route) {
                        shareURL = ShareableURL(url: url)
                    }
                }
            )

            TrakkeIconButton(
                systemImage: "trash",
                role: .destructive,
                accessibilityLabel: String(localized: "common.delete"),
                action: { showDeleteConfirmation = true }
            )
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


    private var backAction: (() -> Void)? {
        guard isEmbedded else { return nil }
        return { dismiss() }
    }
}
