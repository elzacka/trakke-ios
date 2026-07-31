import XCTest

final class TrakkeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
        // Kartet med Kartverket-kreditering og Meny-knappen er alltid til
        // stede ved oppstart (ark-tilstand kan variere) – fanger krasj ved
        // lansering, brutt kartoppsett og manglende påkrevd attribusjon.
        XCTAssertTrue(app.staticTexts["© Kartverket"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Meny"].exists)
    }
}
