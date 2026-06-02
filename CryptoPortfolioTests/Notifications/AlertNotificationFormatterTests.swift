import XCTest
@testable import CryptoPortfolio

final class AlertNotificationFormatterTests: XCTestCase {
    private func firing(_ condition: AlertCondition, coinName: String? = nil) -> AlertFiring {
        AlertFiring(
            alert: PriceAlert(condition: condition, recurrence: .oneShot),
            firedAt: Date()
        )
    }

    func test_priceCrossing_body_includesCoinAndPrice() {
        let body = AlertNotificationFormatter.body(
            for: firing(.priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000)),
            coinName: "Bitcoin",
            currency: .usd
        )
        XCTAssertTrue(body.contains("Bitcoin"))
        XCTAssertTrue(body.contains("75"))
    }

    func test_percentChange_body_includesPercentAndWindow() {
        let body = AlertNotificationFormatter.body(
            for: firing(.percentChange(coinId: "eth", direction: .below, window: .d7, threshold: -5)),
            coinName: "Ethereum",
            currency: .usd
        )
        XCTAssertTrue(body.contains("Ethereum"))
        XCTAssertTrue(body.contains("5"))
        XCTAssertTrue(body.contains("7"))
    }

    func test_portfolioValue_body_mentionsPortfolioAndAmount() {
        let body = AlertNotificationFormatter.body(
            for: firing(.portfolioValue(direction: .above, threshold: 100_000)),
            coinName: nil,
            currency: .usd
        )
        XCTAssertTrue(body.localizedCaseInsensitiveContains("portfolio"))
        XCTAssertTrue(body.contains("100"))
    }

    func test_portfolioPnLPercent_body_mentionsPnL() {
        let body = AlertNotificationFormatter.body(
            for: firing(.portfolioPnLPercent(direction: .below, threshold: -10)),
            coinName: nil,
            currency: .usd
        )
        XCTAssertTrue(body.contains("10"))
        XCTAssertTrue(body.localizedCaseInsensitiveContains("p/l")
                      || body.localizedCaseInsensitiveContains("pnl")
                      || body.localizedCaseInsensitiveContains("kar"))
    }

    func test_titleIsConstant() {
        let firing = firing(.priceCrossing(coinId: "btc", direction: .above, targetPrice: 1))
        XCTAssertEqual(AlertNotificationFormatter.title(for: firing),
                       String(localized: "alerts.notification.title", defaultValue: "Price alert"))
    }
}
