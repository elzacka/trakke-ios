import SwiftUI
import Charts
import CoreLocation

struct ActivityDetailSheet: View {
    @Bindable var viewModel: ActivityViewModel
    let activity: Activity
    var onRetrace: ((CLLocationCoordinate2D) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .Trakke.cardGap) {
                    statsCard
                    elevationCard
                    detailsCard
                    retraceButton
                    deleteButton

                    Spacer(minLength: .Trakke.lg)
                }
                .padding(.horizontal, .Trakke.sheetHorizontal)
                .padding(.top, .Trakke.sheetTop)
            }
            .background(Color(.systemGroupedBackground))
            .tint(Color.Trakke.brand)
            .navigationTitle(activity.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        CardSection(String(localized: "activity.stats")) {
            HStack(spacing: .Trakke.lg) {
                statItem(
                    icon: "arrow.left.and.right",
                    label: String(localized: "activity.distance"),
                    value: ActivityViewModel.formatDistance(activity.distance)
                )
                statItem(
                    icon: "timer",
                    label: String(localized: "activity.duration"),
                    value: ActivityViewModel.formatDuration(activity.duration)
                )
                statItem(
                    icon: "arrow.up.right",
                    label: String(localized: "elevation.gain"),
                    value: "\(Int(activity.elevationGain)) m"
                )
                statItem(
                    icon: "arrow.down.right",
                    label: String(localized: "elevation.loss"),
                    value: "\(Int(activity.elevationLoss)) m"
                )
            }
            .padding(.vertical, .Trakke.xs)
        }
    }

    // MARK: - Elevation Card

    private var elevationCard: some View {
        CardSection(String(localized: "elevation.profile")) {
            if elevationPoints.count >= 2 {
                elevationChart
            } else {
                Text(String(localized: "activity.noElevationData"))
                    .font(Font.Trakke.caption)
                    .foregroundStyle(Color.Trakke.textTertiary)
                    .padding(.vertical, .Trakke.sm)
            }
        }
    }

    @ViewBuilder
    private var elevationChart: some View {
        Chart {
            ForEach(Array(elevationPoints.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value(String(localized: "elevation.distance"), point.distance / 1000),
                    y: .value(String(localized: "elevation.altitude"), point.altitude)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.Trakke.brand.opacity(0.3), Color.Trakke.brand.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value(String(localized: "elevation.distance"), point.distance / 1000),
                    y: .value(String(localized: "elevation.altitude"), point.altitude)
                )
                .foregroundStyle(Color.Trakke.brand)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXAxisLabel(String(localized: "elevation.distanceKm"))
        .chartYAxisLabel("m")
        .frame(height: 160)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        CardSection(String(localized: "activity.details")) {
            detailRow(
                label: String(localized: "activity.date"),
                value: activity.startedAt.formatted(date: .long, time: .shortened)
            )
            Divider().padding(.leading, .Trakke.dividerLeading)
            detailRow(
                label: String(localized: "activity.trackPoints"),
                value: "\(activity.trackPoints.count)"
            )
            if let pace = averagePace {
                Divider().padding(.leading, .Trakke.dividerLeading)
                detailRow(
                    label: String(localized: "activity.averagePace"),
                    value: pace
                )
            }
        }
    }

    // MARK: - Retrace Button

    @ViewBuilder
    private var retraceButton: some View {
        if let startPoint = retraceDestination {
            Button {
                dismiss()
                onRetrace?(startPoint)
            } label: {
                Label(String(localized: "activity.retrace"), systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.trakkeSecondary)
        }
    }

    /// The start point of the track — where the user wants to navigate back to.
    private var retraceDestination: CLLocationCoordinate2D? {
        guard let first = activity.trackPoints.first, first.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: first[1], longitude: first[0])
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Label(String(localized: "activity.delete"), systemImage: "trash")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.trakkeDanger)
        .confirmationDialog(
            String(localized: "activity.delete.title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "activity.delete.confirm"), role: .destructive) {
                viewModel.deleteActivity(activity)
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: .Trakke.labelGap) {
            HStack(spacing: .Trakke.xs) {
                Image(systemName: icon)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                Text(value)
                    .font(Font.Trakke.bodyMedium)
                    .monospacedDigit()
            }
            Text(label)
                .foregroundStyle(Color.Trakke.textTertiary)
                .font(Font.Trakke.captionSoft)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Font.Trakke.bodyRegular)
            Spacer()
            Text(value)
                .font(Font.Trakke.bodyRegular)
                .foregroundStyle(Color.Trakke.textTertiary)
        }
        .padding(.vertical, .Trakke.rowVertical)
    }

    private var averagePace: String? {
        guard activity.distance > 0, activity.duration > 0 else { return nil }
        let paceSecondsPerKm = activity.duration / (activity.distance / 1000)
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        let formatted = String(format: "%d:%02d", minutes, seconds)
        return String(localized: "activity.paceValue \(formatted)")
    }

    private struct ElevPoint {
        let distance: Double
        let altitude: Double
    }

    private var elevationPoints: [ElevPoint] {
        let points = activity.trackPoints
        guard points.count >= 2 else { return [] }

        var result: [ElevPoint] = []
        var cumulativeDistance: Double = 0

        for (index, point) in points.enumerated() {
            guard point.count >= 3 else { continue }
            let altitude = point[2]

            if index > 0, points[index - 1].count >= 2 {
                let prev = CLLocationCoordinate2D(latitude: points[index - 1][1], longitude: points[index - 1][0])
                let curr = CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                cumulativeDistance += Haversine.distance(from: prev, to: curr)
            }

            result.append(ElevPoint(distance: cumulativeDistance, altitude: altitude))
        }

        return result
    }
}
