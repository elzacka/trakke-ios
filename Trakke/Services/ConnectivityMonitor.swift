import Network
import Observation

@MainActor
@Observable
final class ConnectivityMonitor {
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case other
        case none
    }

    var isConnected = true
    /// True when the OS has flagged the path as constrained (Low Data Mode enabled by the user).
    var isConstrained = false
    /// True when the path uses a metered or expensive interface (e.g. cellular, personal hotspot).
    var isExpensive = false
    /// Hvilken nett-grensesnitt-type pathen bruker. Settes ved hver
    /// path-update; brukes f.eks. til å vise «WiFi» eller «Mobildata»
    /// i Info > Om > Nettverksstatus.
    var connectionType: ConnectionType = .none

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "no.tazk.trakke.connectivity")

    func start() {
        stop()
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            let type = Self.classify(path: path)
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
                self?.isConstrained = path.isConstrained
                self?.isExpensive = path.isExpensive
                self?.connectionType = type
            }
        }
        newMonitor.start(queue: queue)
        monitor = newMonitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    nonisolated private static func classify(path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .other
    }
}
