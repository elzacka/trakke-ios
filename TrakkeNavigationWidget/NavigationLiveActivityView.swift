import ActivityKit
import WidgetKit
import SwiftUI

// Brand green (#3e4533) – duplicated here since the widget extension
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
                        Text(context.state.travelTime.map { "\($0) igjen" } ?? "til mål")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
            } compactLeading: {
                // Ingen roterende pil her: på denne plassen er det ikke rom for
                // et nordmerke, og en fritt roterende pil leses som «gå hit».
                // Tallet er entydig.
                Text(context.state.hasArrived
                    ? "Fremme"
                    : "\(context.state.bearing)° \(context.state.cardinalDirection)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(brandGreen)
            } compactTrailing: {
                if !context.state.hasArrived {
                    Text(context.state.distance)
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            } minimal: {
                Image(systemName: context.state.hasArrived
                    ? "flag.checkered" : "location.north.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(brandGreen)
            }
        }
    }
}

// MARK: - Lock Screen View

struct NavigationLockScreenView: View {
    let state: NavigationActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            if state.hasArrived {
                arrivedCell
            } else {
                NavigationBearingCell(state: state)

                Divider()
                    .frame(height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.distance)
                        .font(.title3.monospacedDigit().weight(.semibold))
                    Text(state.travelTime.map { "\($0) igjen" } ?? "til mål")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private var arrivedCell: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.title3.weight(.semibold))
                .foregroundStyle(brandGreen)
            Text("Fremme")
                .font(.headline.weight(.bold))
        }
    }
}

// MARK: - Bearing Cell

struct NavigationBearingCell: View {
    let state: NavigationActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            CompassRose(bearing: state.bearing)

            VStack(alignment: .leading, spacing: 1) {
                Text(state.cardinalDirection)
                    .font(.headline.weight(.bold))
                Text("\(state.bearing)°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Retning mot målet")
        .accessibilityValue("\(state.bearing) grader, \(state.cardinalDirection) fra nord")
    }
}

// MARK: - Kompassrose

/// Retningen vises som en rose med fast nordmerke, ikke som en fritt
/// roterende pil.
///
/// Widget-utvidelsen har ingen tilgang til enhetens kompass, og
/// Live Activity-oppdateringer er for sjeldne til å følge en kroppsvending.
/// En pil uten nordreferanse ville derfor sett ut som «gå denne veien» mens
/// den i virkeligheten peker mot målet regnet fra nord. Nordmerket gjør
/// avlesningen entydig: den kan overføres rett til et fysisk kompass.
/// Den retningen som følger kroppen din finnes i appens nav-bar.
struct CompassRose: View {
    let bearing: Int

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)

            Text("N")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .offset(y: -10)

            Image(systemName: "location.north.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(brandGreen)
                .rotationEffect(.degrees(Double(bearing)))
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}
