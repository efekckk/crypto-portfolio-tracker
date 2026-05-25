import XCTest
@testable import CryptoPortfolio

final class GetPortfolioSummaryUseCaseTests: XCTestCase {
    private func makeSUT(holdings: [Holding], coins: [Coin])
        -> (GetPortfolioSummaryUseCase, MockPortfolioRepository, MockCoinRepository) {
        let portfolioRepo = MockPortfolioRepository()
        for h in holdings { try? portfolioRepo.save(h) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        return (GetPortfolioSummaryUseCase(portfolioRepository: portfolioRepo, coinRepository: coinRepo),
                portfolioRepo, coinRepo)
    }

    func test_emptyPortfolio_returnsEmptySummary() async throws {
        let (sut, _, _) = makeSUT(holdings: [], coins: [])
        let summary = try await sut(currency: .usd)
        XCTAssertEqual(summary, .empty)
    }

    func test_singleHolding_inProfit() async throws {
        let (sut, _, _) = makeSUT(
            holdings: [Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000)],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50000)]
        )

        let summary = try await sut(currency: .usd)

        XCTAssertEqual(summary.totalValue, 100000)
        XCTAssertEqual(summary.totalCost, 80000)
        XCTAssertEqual(summary.absolutePnL, 20000)
        XCTAssertEqual(summary.percentPnL, 25)
        XCTAssertEqual(summary.items.count, 1)
        XCTAssertEqual(summary.items.first?.coin?.id, "bitcoin")
    }

    func test_multipleHoldings_aggregateValueAndPnL() async throws {
        let (sut, _, _) = makeSUT(
            holdings: [
                Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 50000),
                Holding(coinId: "ethereum", amount: 10, averageBuyPrice: 1000)
            ],
            coins: [
                Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 40000),
                Coin(id: "ethereum", symbol: "eth", name: "Ethereum", currentPrice: 2000)
            ]
        )

        let summary = try await sut(currency: .usd)

        XCTAssertEqual(summary.totalValue, 60000)
        XCTAssertEqual(summary.totalCost, 60000)
        XCTAssertEqual(summary.absolutePnL, 0)
        XCTAssertEqual(summary.percentPnL, 0)
        XCTAssertEqual(summary.items.count, 2)
    }

    func test_holdingWithMissingPrice_valuedAtZero() async throws {
        let (sut, _, _) = makeSUT(
            holdings: [Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000)],
            coins: []
        )

        let summary = try await sut(currency: .usd)

        XCTAssertEqual(summary.totalValue, 0)
        XCTAssertEqual(summary.totalCost, 80000)
        XCTAssertEqual(summary.absolutePnL, -80000)
        XCTAssertEqual(summary.items.first?.coin, nil)
    }
}
