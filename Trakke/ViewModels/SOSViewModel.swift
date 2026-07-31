import SwiftUI

/// Manages SOS signal state for the UI.
@MainActor
@Observable
final class SOSViewModel {
    private(set) var isActive = false
    var audioEnabled = true
    private let service = SOSService()
    /// Kjede av start/stop-kall: hvert kall venter på det forrige, slik at
    /// rask av/på aldri kan nå aktoren i motsatt rekkefølge (en forsinket
    /// stop ville ellers drept det nye signalet).
    private var controlTask: Task<Void, Never>?

    var hasTorch: Bool {
        service.hasTorch
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        UIApplication.shared.isIdleTimerDisabled = true
        let withAudio = audioEnabled
        let service = service
        let previous = controlTask
        controlTask = Task {
            await previous?.value
            await service.start(withAudio: withAudio)
        }
    }

    /// Halen av start/stop-kjeden. Brukes av tester for å oppdage regresjoner
    /// der kjeden låser seg (f.eks. et blokkerende `start` som aldri
    /// returnerer). `Task` er Sendable og kan awaites utenfor MainActor.
    var pendingOperations: Task<Void, Never>? { controlTask }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        // Do not reset isIdleTimerDisabled here; AppLifecycleModifier observes
        // isActive and reconciles the keep-awake state across nav/recording/SOS.
        let service = service
        let previous = controlTask
        controlTask = Task {
            await previous?.value
            await service.stop()
        }
    }
}
