import XCTest
@testable import CryptoPortfolio

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
