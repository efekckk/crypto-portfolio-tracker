import XCTest
@testable import CryptoPortfolio

final class PriceAlertTests: XCTestCase {
    func test_legacyConvenienceInit_buildsPriceCrossingOneShot() {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 75000, direction: .above)
        XCTAssertEqual(alert.recurrence, .oneShot)
        XCTAssertEqual(alert.condition,
                       .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000))
        XCTAssertTrue(alert.isActive)
        XCTAssertNil(alert.firedAt)
        XCTAssertNil(alert.lastConditionResult)
    }

    func test_directionAlias_resolvesToAlertConditionDirection() {
        // The convenience init takes PriceAlert.Direction (an alias).
        let above: PriceAlert.Direction = .above
        let below: PriceAlert.Direction = .below
        XCTAssertNotEqual(above, below)
    }

    func test_fullInit_storesAllFields() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 100)
        let alert = PriceAlert(
            id: id,
            condition: .portfolioValue(direction: .above, threshold: 50_000),
            recurrence: .cooldown(seconds: 3600),
            isActive: false,
            firedAt: date,
            lastConditionResult: true
        )
        XCTAssertEqual(alert.id, id)
        XCTAssertEqual(alert.recurrence, .cooldown(seconds: 3600))
        XCTAssertEqual(alert.firedAt, date)
        XCTAssertEqual(alert.lastConditionResult, true)
    }
}
