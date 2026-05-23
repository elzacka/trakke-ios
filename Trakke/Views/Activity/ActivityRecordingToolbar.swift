import SwiftUI

struct ActivityRecordingToolbar: View {
    let formattedDistance: String
    let formattedDuration: String
    let formattedElevationGain: String
    /// Når nav-HUD også er aktiv stables opptaks-pillen under den.
    var stackBelowNav: Bool = false
    var onStop: () -> Void

    var body: some View {
        MapActionBar(position: .top, topOffset: stackBelowNav ? 56 : 0) {
            MapActionRecordingDot()
            MapActionDivider()
            MapActionStat(icon: "timer", value: formattedDuration)
            MapActionDivider()
            MapActionStat(icon: "arrow.left.and.right", value: formattedDistance)
            MapActionDivider()
            MapActionStat(icon: "arrow.up.right", value: formattedElevationGain)
            MapActionDivider()
            MapActionButton(
                systemImage: "stop.fill",
                role: .recording,
                accessibilityLabel: String(localized: "activity.stop"),
                action: onStop
            )
        }
    }
}
