import UIKit

/// Thin wrapper around UINotificationFeedbackGenerator to keep UIKit out of ViewModels.
@MainActor
final class HapticFeedbackService {
    private let generator = UINotificationFeedbackGenerator()

    func prepare() {
        generator.prepare()
    }

    func success() {
        generator.notificationOccurred(.success)
    }

    func warning() {
        generator.notificationOccurred(.warning)
    }

    func error() {
        generator.notificationOccurred(.error)
    }
}
