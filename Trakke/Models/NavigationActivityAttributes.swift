import ActivityKit

struct NavigationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var bearing: Int
        var cardinalDirection: String
        var distance: String
        var isPaused: Bool
    }
}
