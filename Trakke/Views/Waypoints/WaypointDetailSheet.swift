import SwiftUI
import CoreLocation

struct WaypointDetailSheet: View {
    @Bindable var viewModel: WaypointViewModel
    let waypoint: Waypoint
    var onEdit: ((Waypoint) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormat = .dd
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    infoCard
                    coordinatesCard
                    actionsCard

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(waypoint.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        CardSection(String(localized: "waypoints.info")) {
            VStack(alignment: .leading, spacing: 2) {
                Text(waypoint.name)
                    .font(Font.Trakke.bodyMedium)
                if let category = waypoint.category, !category.isEmpty {
                    Text(category)
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)

            if let elevation = waypoint.elevation {
                Divider().padding(.leading, .Trakke.dividerLeading)
                HStack {
                    Label(String(localized: "waypoints.elevation"), systemImage: "mountain.2")
                        .font(Font.Trakke.bodyRegular)
                    Spacer()
                    Text("\(Int(elevation)) moh.")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.Trakke.textSoft)
                }
                .padding(.vertical, .Trakke.xs)
            }

            Divider().padding(.leading, .Trakke.dividerLeading)
            HStack {
                Label(
                    String(localized: "waypoints.showOnMap"),
                    systemImage: waypoint.isVisible ? "eye" : "eye.slash"
                )
                .font(Font.Trakke.bodyRegular)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { waypoint.isVisible },
                    set: { _ in viewModel.toggleVisibility(waypoint) }
                ))
                .labelsHidden()
            }
            .padding(.vertical, .Trakke.xs)
        }
    }

    // MARK: - Coordinates Card

    private var coordinatesCard: some View {
        CardSection(String(localized: "waypoints.coordinates")) {
            if waypoint.coordinates.count >= 2 {
                let coord = CLLocationCoordinate2D(
                    latitude: waypoint.coordinates[1],
                    longitude: waypoint.coordinates[0]
                )
                let formatted = CoordinateService.format(
                    coordinate: coord,
                    format: coordinateFormat
                )
                HStack {
                    Text(formatted.display)
                        .font(.subheadline.monospacedDigit())
                    Spacer()
                    Button {
                        UIPasteboard.general.string = formatted.copyText
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline)
                            .foregroundStyle(Color.Trakke.brand)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(String(localized: "common.copy"))
                }
            }
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        VStack(spacing: .Trakke.sm) {
            Button {
                onEdit?(waypoint)
            } label: {
                Label(String(localized: "common.edit"), systemImage: "pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.trakkeSecondary)

            Button {
                showDeleteConfirmation = true
            } label: {
                Label(String(localized: "common.delete"), systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.trakkeDanger)
            .confirmationDialog(
                String(localized: "waypoints.deleteConfirmTitle"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "common.delete"), role: .destructive) {
                    viewModel.deleteWaypoint(waypoint)
                    dismiss()
                }
            } message: {
                Text(String(localized: "waypoints.deleteConfirmMessage \(waypoint.name)"))
            }
        }
    }
}
