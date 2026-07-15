import ActivityKit
import WidgetKit
import SwiftUI

// Brand green (#3e4533) — duplicated here since the widget extension
// cannot import from the main app target.
private let brandGreen = Color(red: 0.243, green: 0.271, blue: 0.200)

struct TrakkeNavigationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NavigationActivityAttributes.self) { context in
            NavigationLockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    NavigationBearingCell(state: context.state)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.distance)
                            .font(.title3.monospacedDigit().weight(.semibold))
                        Text("til mål")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "location.north.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(brandGreen)
                        .rotationEffect(.degrees(Double(context.state.bearing)))
                    Text("\(context.state.bearing)°")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            } compactTrailing: {
                Text(context.state.distance)
                    .font(.caption.monospacedDigit().weight(.semibold))
            } minimal: {
                Image(systemName: "location.north.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(brandGreen)
                    .rotationEffect(.degrees(Double(context.state.bearing)))
            }
        }
    }
}

// MARK: - Lock Screen View

struct NavigationLockScreenView: View {
    let state: NavigationActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            NavigationBearingCell(state: state)

            Divider()
                .frame(height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.distance)
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text("til mål")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if state.isPaused {
                Image(systemName: "pause.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Bearing Cell

struct NavigationBearingCell: View {
    let state: NavigationActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.north.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(brandGreen)
                .rotationEffect(.degrees(Double(state.bearing)))

            VStack(alignment: .leading, spacing: 1) {
                Text(state.cardinalDirection)
                    .font(.headline.weight(.bold))
                Text("\(state.bearing)°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
