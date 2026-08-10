import ActivityKit

struct NavigationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var bearing: Int
        var cardinalDirection: String
        var distance: String
        var isPaused: Bool
        /// Låseskjermen må vite om ankomst – uten dette fortsatte den å telle
        /// ned mens appen viste «Fremme».
        var hasArrived: Bool
    }
}
