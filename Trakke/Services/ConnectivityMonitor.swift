import Network
import Observation

@MainActor
@Observable
final class ConnectivityMonitor {
    var isConnected = true
    /// True when the OS has flagged the path as constrained (Low Data Mode enabled by the user).
    var isConstrained = false
    /// True when the path uses a metered or expensive interface (e.g. cellular, personal hotspot).
    var isExpensive = false
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "no.tazk.trakke.connectivity")

    func start() {
        stop()
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
                self?.isConstrained = path.isConstrained
                self?.isExpensive = path.isExpensive
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
