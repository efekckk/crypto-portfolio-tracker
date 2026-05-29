import XCTest
@testable import CryptoPortfolio

@MainActor
final class AddCoinViewModelTests: XCTestCase {

    private func makeSUT(searchResult: [Coin] = [], searchError: Error? = nil)
        -> (AddCoinViewModel, MockCoinRepository, MockPortfolioRepository) {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = searchResult
        coinRepo.errorToThrow = searchError
        let portfolioRepo = MockPortfolioRepository()
        let vm = AddCoinViewModel(
            searchCoins: SearchCoinsUseCase(coinRepository: coinRepo),
            addHolding: AddHoldingUseCase(portfolioRepository: portfolioRepo)
        )
        return (vm, coinRepo, portfolioRepo)
    }

    func test_initialResults_areEmpty() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.results, .empty)
    }

    func test_search_withBlankQuery_stays_empty_andDoesNotCallRepo() async {
        let (sut, coinRepo, _) = makeSUT()
        sut.query = "   "
        await sut.search()
        XCTAssertEqual(sut.results, .empty)
        XCTAssertNil(coinRepo.lastSearchQuery)
    }

    func test_search_withHits_setsLoaded() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")
        let (sut, _, _) = makeSUT(searchResult: [coin])
        sut.query = "bit"
        await sut.search()
        XCTAssertEqual(sut.results, .loaded([coin]))
    }

    func test_search_withNoHits_setsEmpty() async {
        let (sut, _, _) = makeSUT(searchResult: [])
        sut.query = "zzz"
        await sut.search()
        XCTAssertEqual(sut.results, .empty)
    }

    func test_search_failure_setsError() async {
        let (sut, _, _) = makeSUT(searchError: APIError.rateLimited)
        sut.query = "bit"
        await sut.search()
        if case .error = sut.results { } else { XCTFail("Expected .error, got \(sut.results)") }
    }

    func test_add_valid_savesAndReturnsTrue() async {
        let (sut, _, portfolioRepo) = makeSUT()
        let saved = await sut.add(coinId: "bitcoin", amount: 2, buyPrice: 50000)
        XCTAssertTrue(saved)
        XCTAssertNil(sut.saveError)
        XCTAssertEqual(try? portfolioRepo.holding(coinId: "bitcoin")?.amount, 2)
    }

    func test_add_zeroAmount_returnsFalse_andSetsSaveError() async {
        let (sut, _, _) = makeSUT()
        let saved = await sut.add(coinId: "bitcoin", amount: 0, buyPrice: 100)
        XCTAssertFalse(saved)
        XCTAssertNotNil(sut.saveError)
    }
}
