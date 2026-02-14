import SwiftUI

struct RouteDetailSheet: View {
    @Bindable var viewModel: RouteViewModel
    let route: Route
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var gpxURL: URL?

    var body: some View {
        NavigationStack {
            List {
                routeInfoSection
                elevationSection
                actionsSection
            }
            .navigationTitle(route.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = gpxURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Sections

    private var routeInfoSection: some View {
        Section {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: route.color ?? "#3e4533"))
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(route.name)
                        .font(.headline)
                    Text(viewModel.formattedDistance(route.distance))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let gain = route.elevationGain, gain > 0 {
                HStack {
                    Label(String(localized: "elevation.gain"), systemImage: "arrow.up.right")
                    Spacer()
                    Text("\(Int(gain)) m")
                        .monospacedDigit()
                }
            }

            if let loss = route.elevationLoss, loss > 0 {
                HStack {
                    Label(String(localized: "elevation.loss"), systemImage: "arrow.down.right")
                    Spacer()
                    Text("\(Int(loss)) m")
                        .monospacedDigit()
                }
            }

            HStack {
                Label(String(localized: "route.points"), systemImage: "mappin.and.ellipse")
                Spacer()
                Text("\(route.coordinates.count)")
                    .monospacedDigit()
            }
        }
    }

    private var elevationSection: some View {
        Section(String(localized: "elevation.profile")) {
            if viewModel.isLoadingElevation {
                HStack {
                    ProgressView()
                    Text(String(localized: "elevation.loading"))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            } else if !viewModel.elevationProfile.isEmpty {
                ElevationProfileView(
                    points: viewModel.elevationProfile,
                    stats: viewModel.elevationStats
                )
                .padding(.vertical, 4)
            } else {
                Text(String(localized: "elevation.unavailable"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                gpxURL = viewModel.exportGPX(for: route)
                if gpxURL != nil {
                    showShareSheet = true
                }
            } label: {
                Label(String(localized: "gpx.export"), systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                viewModel.deleteRoute(route)
                dismiss()
            } label: {
                Label(String(localized: "common.delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
