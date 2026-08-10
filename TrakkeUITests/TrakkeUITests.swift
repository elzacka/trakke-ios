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
        //
        // Slås et kartlag på, får krediteringen et tillegg: «© Kartverket |
        // © NVE». Testen slår derfor opp på identifikator og sjekker prefiks,
        // ikke hele strengen – ellers feiler den på en simulator der noen har
        // latt et lag stå på.
        let attribution = app.staticTexts["map.attribution"]
        XCTAssertTrue(attribution.waitForExistence(timeout: 15))
        XCTAssertTrue(
            attribution.label.hasPrefix("© Kartverket"),
            "Kartverket-kreditering mangler, fant: \(attribution.label)"
        )
        XCTAssertTrue(app.buttons["Meny"].exists)
    }
}
