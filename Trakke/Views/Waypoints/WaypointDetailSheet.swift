import SwiftUI
import CoreLocation

struct WaypointDetailSheet: View {
    @Bindable var viewModel: WaypointViewModel
    let waypoint: Waypoint
    var onEdit: ((Waypoint) -> Void)?
    var onNavigate: ((CLLocationCoordinate2D) -> Void)?
    var isEmbedded = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.coordinateFormat) private var coordinateFormat: CoordinateFormat = .dd
    @State private var showDeleteConfirmation = false
    @State private var copied = false
    @State private var shareURL: ShareableURL?

    var body: some View {
        VStack(spacing: 0) {
            if !isEmbedded {
                TrakkeSheetHeader(title: waypoint.name)
            }

            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    actionsCard
                    infoCard
                    coordinatesCard

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, isEmbedded ? .Trakke.sheetTop : .Trakke.sm)
                .padding(.bottom, .Trakke.xxl)
            }
        }
        .background(Color.Trakke.background)
        .tint(Color.Trakke.brand)
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
        }
        .modifier(WaypointEmbeddedNavTitleModifier(isEmbedded: isEmbedded, title: waypoint.name))
    }

    // MARK: - Info Card

    private var infoCard: some View {
        CardSection(String(localized: "waypoints.info")) {
            VStack(alignment: .leading, spacing: .Trakke.labelGap) {
                Text(waypoint.name)
                    .font(Font.Trakke.bodyMedium)
                if let category = waypoint.category, !category.isEmpty {
                    Text(category)
                        .font(Font.Trakke.caption)
                        .foregroundStyle(Color.Trakke.textSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .Trakke.rowVertical)

            if let det = waypoint.details, !det.isEmpty {
                Divider().padding(.leading, .Trakke.dividerLeading)
                Text(det)
                    .font(Font.Trakke.bodyRegular)
                    .foregroundStyle(Color.Trakke.textSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, .Trakke.rowVertical)
            }

            if let elevation = waypoint.elevation {
                Divider().padding(.leading, .Trakke.dividerLeading)
                HStack {
                    Label(String(localized: "waypoints.elevation"), systemImage: "mountain.2")
                        .font(Font.Trakke.bodyRegular)
                    Spacer()
                    Text("\(Int(elevation)) moh.")
                        .font(Font.Trakke.bodyRegular.monospacedDigit())
                        .foregroundStyle(Color.Trakke.textSoft)
                }
                .padding(.vertical, .Trakke.rowVertical)
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
                .toggleStyle(.trakke)
                .accessibilityLabel(String(localized: "waypoints.showOnMap"))
            }
            .padding(.vertical, .Trakke.rowVertical)
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
                        .font(Font.Trakke.bodyRegular.monospacedDigit())
                    Spacer()
                    Button {
                        UIPasteboard.general.setItems(
                            [["public.utf8-plain-text": formatted.copyText]],
                            options: [.expirationDate: Date().addingTimeInterval(300)]
                        )
                        copied = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(1500))
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(Font.Trakke.bodyRegular)
                            .foregroundStyle(Color.Trakke.brandLight)
                            .frame(minWidth: .Trakke.touchMin, minHeight: .Trakke.touchMin)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(String(localized: "common.copy"))
                }
            }
        }
    }

    // MARK: - Actions Card

    // Høyrejustert ikon-bar — samme stil som Naviger-list-fanene og de
    // andre detail-arkene. Posisjon i HStack indikerer hierarki:
    // primær-handling (naviger) først, destruktiv (slett) sist.
    private var actionsCard: some View {
        HStack(spacing: .Trakke.sm) {
            Spacer()

            if waypoint.coordinates.count >= 2 {
                TrakkeIconButton(
                    systemImage: "location.north.fill",
                    accessibilityLabel: String(localized: "navigation.navigateHere"),
                    action: {
                        let coord = CLLocationCoordinate2D(
                            latitude: waypoint.coordinates[1],
                            longitude: waypoint.coordinates[0]
                        )
                        onNavigate?(coord)
                    }
                )
            }

            TrakkeIconButton(
                systemImage: "pencil",
                accessibilityLabel: String(localized: "common.edit"),
                action: { onEdit?(waypoint) }
            )

            TrakkeIconButton(
                systemImage: "square.and.arrow.down",
                accessibilityLabel: String(localized: "export.share"),
                action: {
                    if let url = viewModel.exportGPX(for: waypoint) {
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
                title: String(localized: "waypoints.deleteConfirmTitle"),
                message: String(localized: "waypoints.deleteConfirmMessage \(waypoint.name)"),
                primary: .destructive(String(localized: "common.yes")) {
                    viewModel.deleteWaypoint(waypoint)
                    dismiss()
                },
                cancel: .cancel(String(localized: "common.no"))
            )
        }
    }
}

/// Setter navigationTitle bare når viewet er pushet (isEmbedded), så parent
/// NavigationStack viser tittel og back-knapp i toolbaren. Når viewet
/// presenteres som top-level sheet, viser TrakkeSheetHeader tittelen i stedet.
private struct WaypointEmbeddedNavTitleModifier: ViewModifier {
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
