import UIKit

/// Thin wrapper around feedback generators to keep UIKit out of ViewModels.
@MainActor
final class HapticFeedbackService {
    private let notification = UINotificationFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    func prepare() {
        notification.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
    }

    func success() {
        notification.notificationOccurred(.success)
    }

    func warning() {
        notification.notificationOccurred(.warning)
    }

    func error() {
        notification.notificationOccurred(.error)
    }

    /// Subtle nudge for upcoming events (e.g., 50 m before a turn).
    func tap() {
        lightImpact.impactOccurred()
    }

    /// Firmer nudge for imminent events (e.g., 15 m before a turn).
    func nudge() {
        mediumImpact.impactOccurred()
    }
}
