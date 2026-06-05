import XCTest
@testable import CryptoPortfolio

final class AlertNotificationFormatterTests: XCTestCase {
    private func firing(_ condition: AlertCondition,
                        actualValue: Double? = nil,
                        coinName: String? = nil) -> AlertFiring {
        AlertFiring(
            alert: PriceAlert(condition: condition, recurrence: .oneShot),
            firedAt: Date(),
            actualValue: actualValue,
            coinName: coinName
        )
    }

    func test_priceCrossing_body_withoutActual_namesTargetPrice() {
        let body = AlertNotificationFormatter.body(
            for: firing(.priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000),
                        coinName: "Bitcoin"),
            currency: .usd
        )
        XCTAssertTrue(body.contains("Bitcoin"))
        XCTAssertTrue(body.contains("75"))
    }

    func test_priceCrossing_body_withActual_namesMeasuredPrice() {
        let body = AlertNotificationFormatter.body(
            for: firing(.priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000),
                        actualValue: 80123,
                        coinName: "Bitcoin"),
            currency: .usd
        )
        XCTAssertTrue(body.contains("Bitcoin"))
        XCTAssertTrue(body.contains("80"))
    }

    func test_percentChange_body_withoutActual_namesThresholdAndWindow() {
        let body = AlertNotificationFormatter.body(
            for: firing(.percentChange(coinId: "eth", direction: .below, window: .d7, threshold: -5),
                        coinName: "Ethereum"),
            currency: .usd
        )
        XCTAssertTrue(body.contains("Ethereum"))
        XCTAssertTrue(body.contains("5"))
        XCTAssertTrue(body.contains("7"))
    }

    func test_percentChange_body_withActual_namesMeasuredMove() {
        let body = AlertNotificationFormatter.body(
            for: firing(.percentChange(coinId: "eth", direction: .above, window: .h24, threshold: 5),
                        actualValue: 8.2,
                        coinName: "Ethereum"),
            currency: .usd
        )
        XCTAssertTrue(body.contains("Ethereum"))
        XCTAssertTrue(body.contains("8"))
        XCTAssertTrue(body.contains("24"))
    }

    func test_portfolioValue_body_usesActualWhenAvailable() {
        let body = AlertNotificationFormatter.body(
            for: firing(.portfolioValue(direction: .above, threshold: 100_000),
                        actualValue: 120_000),
            currency: .usd
        )
        XCTAssertTrue(body.localizedCaseInsensitiveContains("portfolio"))
        XCTAssertTrue(body.contains("120"))
    }

    func test_portfolioValue_body_fallsBackToThreshold() {
        let body = AlertNotificationFormatter.body(
            for: firing(.portfolioValue(direction: .above, threshold: 100_000)),
            currency: .usd
        )
        XCTAssertTrue(body.localizedCaseInsensitiveContains("portfolio"))
        XCTAssertTrue(body.contains("100"))
    }

    func test_portfolioPnLPercent_body_usesActualWhenAvailable() {
        let body = AlertNotificationFormatter.body(
            for: firing(.portfolioPnLPercent(direction: .below, threshold: -10),
                        actualValue: -22.5),
            currency: .usd
        )
        XCTAssertTrue(body.contains("22"))
    }

    func test_priceCrossing_body_fallsBackToCapitalisedCoinId_whenNoCoinName() {
        let body = AlertNotificationFormatter.body(
            for: firing(.priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000)),
            currency: .usd
        )
        XCTAssertTrue(body.contains("Bitcoin"))
    }

    func test_titleIsConstant() {
        let f = firing(.priceCrossing(coinId: "btc", direction: .above, targetPrice: 1))
        XCTAssertEqual(AlertNotificationFormatter.title(for: f),
                       String(localized: "alerts.notification.title", defaultValue: "Alert"))
    }
}
