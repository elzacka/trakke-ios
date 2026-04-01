import SwiftUI

/// Manages SOS signal state for the UI.
@MainActor
@Observable
final class SOSViewModel {
    private(set) var isActive = false
    var audioEnabled = true
    private let service = SOSService()
    private var signalTask: Task<Void, Never>?

    var hasTorch: Bool {
        service.hasTorch
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        let withAudio = audioEnabled
        signalTask = Task { [weak self] in
            await self?.service.start(withAudio: withAudio)
        }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        signalTask?.cancel()
        signalTask = nil
        Task { [weak self] in await self?.service.stop() }
    }
}
