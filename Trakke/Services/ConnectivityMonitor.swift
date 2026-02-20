import Network
import Observation

@MainActor
@Observable
final class ConnectivityMonitor {
    var isConnected = true
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "no.tazk.trakke.connectivity")

    func start() {
        stop()
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        newMonitor.start(queue: queue)
        monitor = newMonitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }
}
