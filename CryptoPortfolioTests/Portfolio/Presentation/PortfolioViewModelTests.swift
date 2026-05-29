import XCTest
@testable import CryptoPortfolio

@MainActor
final class PortfolioViewModelTests: XCTestCase {

    private func makeSUT(holdings: [Holding] = [], coins: [Coin] = [], error: Error? = nil)
        -> (PortfolioViewModel, MockPortfolioRepository, MockCoinRepository) {
        let portfolioRepo = MockPortfolioRepository()
        for h in holdings { try? portfolioRepo.save(h) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        coinRepo.errorToThrow = error
        let vm = PortfolioViewModel(
            getSummary: GetPortfolioSummaryUseCase(portfolioRepository: portfolioRepo, coinRepository: coinRepo),
            removeHolding: RemoveHoldingUseCase(portfolioRepository: portfolioRepo),
            currency: .usd
        )
        return (vm, portfolioRepo, coinRepo)
    }

    func test_initialState_isLoading() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.state, .loading)
    }

    func test_load_setsEmptyForNoHoldings() async {
        let (sut, _, _) = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_load_setsLoadedWithSummaryForNonEmptyPortfolio() async {
        let (sut, _, _) = makeSUT(
            holdings: [Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000)],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50000)]
        )
        await sut.load()
        guard case .loaded(let summary) = sut.state else {
            XCTFail("Expected .loaded, got \(sut.state)"); return
        }
        XCTAssertEqual(summary.totalValue, 100000)
        XCTAssertEqual(summary.absolutePnL, 20000)
        XCTAssertEqual(summary.items.count, 1)
    }

    func test_load_setsErrorOnNetworkFailure() async {
        let (sut, _, _) = makeSUT(
            holdings: [Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100)],
            coins: [],
            error: APIError.rateLimited
        )
        await sut.load()
        guard case .error(let message) = sut.state else {
            XCTFail("Expected .error, got \(sut.state)"); return
        }
        XCTAssertTrue(message.lowercased().contains("rate"),
                      "Expected a rate-limit-related message, got '\(message)'")
    }

    func test_delete_removesHoldingAndReloads() async {
        let (sut, portfolioRepo, _) = makeSUT(
            holdings: [
                Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100),
                Holding(coinId: "ethereum", amount: 5, averageBuyPrice: 2000)
            ],
            coins: [
                Coin(id: "ethereum", symbol: "eth", name: "Ethereum", currentPrice: 2000)
            ]
        )
        await sut.load()
        await sut.delete(coinId: "bitcoin")

        XCTAssertNil(try? portfolioRepo.holding(coinId: "bitcoin"))
        if case .loaded(let summary) = sut.state {
            XCTAssertEqual(summary.items.map(\.holding.coinId), ["ethereum"])
        } else {
            XCTFail("Expected .loaded after delete, got \(sut.state)")
        }
    }

    func test_refresh_isEquivalentToLoad() async {
        let (sut, _, _) = makeSUT()
        await sut.refresh()
        XCTAssertEqual(sut.state, .empty)
    }
}
