import Network
import Observation

@MainActor
@Observable
final class ConnectivityMonitor {
    var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "no.tazk.trakke.connectivity")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
