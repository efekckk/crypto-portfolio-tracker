import XCTest
@testable import CryptoPortfolio

// MARK: - Mocks (reused by GetPortfolioSummaryUseCaseTests in the same target)

final class MockCoinRepository: CoinRepository {
    var searchResult: [Coin] = []
    var marketsResult: [Coin] = []
    private(set) var lastSearchQuery: String?

    func searchCoins(query: String) async throws -> [Coin] {
        lastSearchQuery = query
        return searchResult
    }
    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        marketsResult
    }
}

final class MockPortfolioRepository: PortfolioRepository {
    var storage: [String: Holding] = [:]

    func holdings() throws -> [Holding] {
        storage.values.sorted { $0.coinId < $1.coinId }
    }
    func holding(coinId: String) throws -> Holding? { storage[coinId] }
    func save(_ holding: Holding) throws { storage[holding.coinId] = holding }
    func remove(coinId: String) throws { storage[coinId] = nil }
}

final class PortfolioUseCasesTests: XCTestCase {
    func test_searchCoins_delegatesToRepository() async throws {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")]
        let sut = SearchCoinsUseCase(coinRepository: coinRepo)

        let result = try await sut("bit")

        XCTAssertEqual(coinRepo.lastSearchQuery, "bit")
        XCTAssertEqual(result.map(\.id), ["bitcoin"])
    }

    func test_addHolding_createsNewHoldingWhenAbsent() throws {
        let repo = MockPortfolioRepository()
        let sut = AddHoldingUseCase(portfolioRepository: repo)

        try sut(coinId: "bitcoin", amount: 2, buyPrice: 40000)

        let saved = try repo.holding(coinId: "bitcoin")
        XCTAssertEqual(saved?.amount, 2)
        XCTAssertEqual(saved?.averageBuyPrice, 40000)
    }

    func test_addHolding_mergesWithWeightedAverageBuyPrice() throws {
        let repo = MockPortfolioRepository()
        try repo.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 30000))
        let sut = AddHoldingUseCase(portfolioRepository: repo)

        // Add 3 more units at 50000 => total 4 units, avg = (1*30000 + 3*50000)/4 = 45000
        try sut(coinId: "bitcoin", amount: 3, buyPrice: 50000)

        let saved = try repo.holding(coinId: "bitcoin")
        XCTAssertEqual(saved?.amount, 4)
        XCTAssertEqual(saved?.averageBuyPrice, 45000)
    }

    func test_addHolding_throwsOnNonPositiveAmount() {
        let repo = MockPortfolioRepository()
        let sut = AddHoldingUseCase(portfolioRepository: repo)

        XCTAssertThrowsError(try sut(coinId: "bitcoin", amount: 0, buyPrice: 100)) { error in
            XCTAssertEqual(error as? PortfolioError, .invalidAmount)
        }
    }

    func test_removeHolding_delegatesToRepository() throws {
        let repo = MockPortfolioRepository()
        try repo.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100))
        let sut = RemoveHoldingUseCase(portfolioRepository: repo)

        try sut(coinId: "bitcoin")

        XCTAssertNil(try repo.holding(coinId: "bitcoin"))
    }
}
