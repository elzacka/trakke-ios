import SwiftUI
import Charts

struct ElevationProfileView: View {
    let points: [ElevationPoint]
    let stats: ElevationStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "elevation.profile"))
                .font(.headline)

            if let stats {
                statsRow(stats)
            }

            chart
        }
    }

    private var chart: some View {
        Chart(Array(points.enumerated()), id: \.offset) { _, point in
            AreaMark(
                x: .value("Avstand", point.distance / 1000),
                y: .value("Høyde", point.elevation)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [Color.Trakke.brand.opacity(0.3), Color.Trakke.brand.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Avstand", point.distance / 1000),
                y: .value("Høyde", point.elevation)
            )
            .foregroundStyle(Color.Trakke.brand)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxisLabel(String(localized: "elevation.distanceKm"))
        .chartYAxisLabel("m")
        .frame(height: 160)
    }

    private func statsRow(_ stats: ElevationStats) -> some View {
        HStack(spacing: 16) {
            statItem(
                icon: "arrow.up.right",
                label: String(localized: "elevation.gain"),
                value: "\(stats.gain) m"
            )
            statItem(
                icon: "arrow.down.right",
                label: String(localized: "elevation.loss"),
                value: "\(stats.loss) m"
            )
            statItem(
                icon: "arrow.up",
                label: String(localized: "elevation.max"),
                value: "\(stats.max) m"
            )
            statItem(
                icon: "arrow.down",
                label: String(localized: "elevation.min"),
                value: "\(stats.min) m"
            )
        }
        .font(.caption)
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            Text(label)
                .foregroundStyle(.secondary)
                .font(.caption2)
        }
    }
}
