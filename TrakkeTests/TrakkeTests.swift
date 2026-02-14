import Testing
@testable import Trakke

@Test func routeCreation() async throws {
    let route = Route(name: "Testtur")
    #expect(route.name == "Testtur")
    #expect(route.id.hasPrefix("route-"))
    #expect(route.coordinates.isEmpty)
}

@Test func waypointCreation() async throws {
    let wp = Waypoint(name: "Utsiktspunkt", coordinates: [10.7522, 59.9139])
    #expect(wp.name == "Utsiktspunkt")
    #expect(wp.id.hasPrefix("wp-"))
    #expect(wp.coordinates.count == 2)
}
