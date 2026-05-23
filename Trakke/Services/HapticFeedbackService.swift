import UIKit

/// Thin wrapper around feedback generators to keep UIKit out of ViewModels.
/// Use as a namespace: `HapticFeedback.success()`, `HapticFeedback.prepare()`.
@MainActor
enum HapticFeedback {
    private static let notification = UINotificationFeedbackGenerator()
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    static func prepare() {
        notification.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
    }

    static func success() {
        notification.notificationOccurred(.success)
    }

    static func warning() {
        notification.notificationOccurred(.warning)
    }

    static func error() {
        notification.notificationOccurred(.error)
    }

    /// Subtle nudge for upcoming events (e.g., 50 m before a turn).
    static func tap() {
        lightImpact.impactOccurred()
    }

    /// Firmer nudge for imminent events (e.g., 15 m before a turn).
    static func nudge() {
        mediumImpact.impactOccurred()
    }
}
