import XCTest
@testable import CryptoPortfolio

final class AppContainerTests: XCTestCase {
    private func makeSUT() -> AppContainer {
        AppContainer(coreDataStack: CoreDataStack(inMemory: true))
    }

    func test_buildsPortfolioUseCases() throws {
        let container = makeSUT()

        try container.makeAddHoldingUseCase()(coinId: "bitcoin", amount: 1, buyPrice: 100)
        let holdings = try container.portfolioRepository.holdings()

        XCTAssertEqual(holdings.map(\.coinId), ["bitcoin"])
    }

    func test_summaryUseCaseReturnsEmptyForNoHoldings() async throws {
        let container = makeSUT()
        let summary = try await container.makeGetPortfolioSummaryUseCase()(currency: .usd)
        XCTAssertEqual(summary, .empty)
    }

    func test_buildsCoinDetailUseCases() throws {
        let container = makeSUT()
        let chart = container.makeGetCoinChartUseCase()
        let market = container.makeGetCoinMarketUseCase()
        XCTAssertNotNil(chart)
        XCTAssertNotNil(market)
        _ = chart
        _ = market
    }

    func test_buildsWatchlistUseCases() throws {
        let container = makeSUT()
        let get = container.makeGetWatchlistUseCase()
        let toggle = container.makeToggleWatchlistUseCase()
        XCTAssertNotNil(get); XCTAssertNotNil(toggle)
        _ = get; _ = toggle
    }
}
