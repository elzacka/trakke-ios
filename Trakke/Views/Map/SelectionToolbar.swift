import SwiftUI

struct SelectionToolbar: View {
    let hasValidSelection: Bool
    let estimatedTileCount: Int
    let estimatedSize: String
    var onCancel: () -> Void
    var onDone: () -> Void

    var body: some View {
        MapActionBar(position: .top) {
            if hasValidSelection {
                MapActionStat(
                    icon: estimatedTileCount > 20_000 ? "exclamationmark.triangle.fill" : "square.grid.3x3",
                    value: "\(estimatedTileCount) (\(estimatedSize))",
                    color: estimatedTileCount > 20_000 ? Color.Trakke.red : Color.Trakke.text,
                    accessibilityLabel: estimatedTileCount > 20_000
                        ? String(localized: "offline.tooManyTiles")
                        : String(localized: "offline.tiles \(estimatedTileCount)")
                )
            } else {
                MapActionHint(text: String(localized: "offline.selectAreaHint"))
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
                systemImage: "checkmark",
                role: .primary,
                isEnabled: hasValidSelection,
                accessibilityLabel: String(localized: "common.done"),
                action: onDone
            )
        }
    }
}
