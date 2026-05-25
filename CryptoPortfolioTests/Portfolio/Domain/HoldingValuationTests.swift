import XCTest
@testable import CryptoPortfolio

final class HoldingValuationTests: XCTestCase {
    func test_profitLossComputedFromValueAndCost() {
        let valuation = HoldingValuation(
            holding: Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000),
            coin: nil,
            currentValue: 100000,
            cost: 80000
        )

        XCTAssertEqual(valuation.absolutePnL, 20000)
        XCTAssertEqual(valuation.percentPnL, 25)
    }

    func test_percentPnLIsZeroWhenCostIsZero() {
        let valuation = HoldingValuation(
            holding: Holding(coinId: "x", amount: 1, averageBuyPrice: 0),
            coin: nil,
            currentValue: 50,
            cost: 0
        )

        XCTAssertEqual(valuation.percentPnL, 0)
    }

    func test_emptySummaryHasZeros() {
        XCTAssertEqual(PortfolioSummary.empty.totalValue, 0)
        XCTAssertEqual(PortfolioSummary.empty.absolutePnL, 0)
        XCTAssertTrue(PortfolioSummary.empty.items.isEmpty)
    }
}
