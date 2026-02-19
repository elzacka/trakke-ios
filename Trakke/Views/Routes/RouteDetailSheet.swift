import SwiftUI

struct RouteDetailSheet: View {
    @Bindable var viewModel: RouteViewModel
    let route: Route
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: ShareableURL?

    var body: some View {
        NavigationStack {
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
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $shareURL) { item in
                ShareSheet(activityItems: [item.url])
            }
        }
    }

    // MARK: - Route Info

    private var routeInfoCard: some View {
        CardSection(String(localized: "route.info")) {
            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(Font.Trakke.bodyMedium)
                Text(viewModel.formattedDistance(route.distance))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textSoft)
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
                        .foregroundStyle(Color.Trakke.textSoft)
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
                    .foregroundStyle(Color.Trakke.textSoft)
                    .padding(.vertical, .Trakke.xs)
            }
        }
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: .Trakke.sm) {
            Button {
                if let url = viewModel.exportGPX(for: route) {
                    shareURL = ShareableURL(url: url)
                }
            } label: {
                Label(String(localized: "gpx.export"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.trakkeSecondary)

            Button {
                viewModel.deleteRoute(route)
                dismiss()
            } label: {
                Label(String(localized: "common.delete"), systemImage: "trash")
            }
            .buttonStyle(.trakkeDanger)
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, icon: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(Font.Trakke.bodyRegular)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.Trakke.textSoft)
        }
        .padding(.vertical, .Trakke.xs)
    }

}

// MARK: - Shareable URL

struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
