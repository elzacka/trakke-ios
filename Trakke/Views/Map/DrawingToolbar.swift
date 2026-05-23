import SwiftUI

struct DrawingToolbar: View {
    let pointCount: Int
    let formattedDistance: String
    var onCancel: () -> Void
    var onUndo: () -> Void
    var onDone: () -> Void

    var body: some View {
        MapActionBar(position: .top) {
            if pointCount >= 2 {
                MapActionStat(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    value: formattedDistance,
                    accessibilityLabel: String(localized: "accessibility.route.distance \(formattedDistance)")
                )
            } else {
                MapActionHint(text: String(localized: "route.drawingHint"))
            }

            MapActionDivider()
            MapActionButton(
                systemImage: "xmark",
                role: .destructive,
                accessibilityLabel: String(localized: "common.cancel"),
                action: onCancel
            )
            MapActionDivider()
            MapActionButton(
                systemImage: "arrow.uturn.backward",
                isEnabled: pointCount > 0,
                accessibilityLabel: String(localized: "route.undo"),
                action: onUndo
            )
            MapActionDivider()
            MapActionButton(
                systemImage: "checkmark",
                role: .primary,
                isEnabled: pointCount >= 2,
                accessibilityLabel: String(localized: "common.done"),
                action: onDone
            )
        }
    }
}
