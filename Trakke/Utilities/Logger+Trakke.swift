import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "no.tazk.trakke"

    static let map = Logger(subsystem: subsystem, category: "map")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
    static let knowledge = Logger(subsystem: subsystem, category: "knowledge")
    static let activity = Logger(subsystem: subsystem, category: "activity")
    static let poi = Logger(subsystem: subsystem, category: "poi")
    static let offline = Logger(subsystem: subsystem, category: "offline")
    static let weather = Logger(subsystem: subsystem, category: "weather")
    static let sos = Logger(subsystem: subsystem, category: "sos")
    static let routes = Logger(subsystem: subsystem, category: "routes")
    static let waypoints = Logger(subsystem: subsystem, category: "waypoints")
}
