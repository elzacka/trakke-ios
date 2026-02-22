import SwiftUI
import Charts

struct ElevationProfileView: View {
    let points: [ElevationPoint]
    let stats: ElevationStats?
    var currentDistance: Double?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: .Trakke.sm) {
            if let stats {
                statsRow(stats)
            }

            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value(String(localized: "elevation.distance"), point.distance / 1000),
                    y: .value(String(localized: "elevation.altitude"), point.elevation)
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
                    y: .value(String(localized: "elevation.altitude"), point.elevation)
                )
                .foregroundStyle(Color.Trakke.brand)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            if let currentDistance {
                RuleMark(x: .value(String(localized: "elevation.position"), currentDistance / 1000))
                    .foregroundStyle(Color.Trakke.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXAxisLabel(String(localized: "elevation.distanceKm"))
        .chartYAxisLabel("m")
        .frame(height: sizeClass == .regular ? 240 : 160)
    }

    private func statsRow(_ stats: ElevationStats) -> some View {
        HStack(spacing: .Trakke.lg) {
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
        .font(Font.Trakke.caption)
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: .Trakke.xs) {
                Image(systemName: icon)
                    .font(Font.Trakke.captionSoft)
                    .foregroundStyle(Color.Trakke.textTertiary)
                Text(value)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            Text(label)
                .foregroundStyle(Color.Trakke.textTertiary)
                .font(Font.Trakke.captionSoft)
        }
    }
}
