import XCTest
@testable import CryptoPortfolio

@MainActor
final class AddToWatchlistViewModelTests: XCTestCase {

    private func makeSUT(searchResult: [Coin] = [], initiallyWatched: [String] = [], searchError: Error? = nil)
        -> (AddToWatchlistViewModel, MockCoinRepository, MockWatchlistRepository) {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = searchResult
        coinRepo.errorToThrow = searchError
        let watchRepo = MockWatchlistRepository()
        for id in initiallyWatched { try? watchRepo.add(coinId: id) }
        let vm = AddToWatchlistViewModel(
            searchCoins: SearchCoinsUseCase(coinRepository: coinRepo),
            toggleWatchlist: ToggleWatchlistUseCase(watchlistRepository: watchRepo),
            watchlistRepository: watchRepo
        )
        return (vm, coinRepo, watchRepo)
    }

    func test_initialResults_areEmpty() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.results, .empty)
    }

    func test_search_setsLoadedWithHits() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")
        let (sut, _, _) = makeSUT(searchResult: [coin])
        sut.query = "bit"
        await sut.search()
        XCTAssertEqual(sut.results, .loaded([coin]))
    }

    func test_search_blankQueryStaysEmpty() async {
        let (sut, coinRepo, _) = makeSUT()
        sut.query = "   "
        await sut.search()
        XCTAssertEqual(sut.results, .empty)
        XCTAssertNil(coinRepo.lastSearchQuery)
    }

    func test_isWatched_reflectsRepositoryState() async {
        let (sut, _, _) = makeSUT(initiallyWatched: ["bitcoin"])
        await sut.refreshWatchedIds()
        XCTAssertTrue(sut.isWatched(coinId: "bitcoin"))
        XCTAssertFalse(sut.isWatched(coinId: "ethereum"))
    }

    func test_toggle_addsWhenNotWatched_andRefreshesState() async {
        let (sut, _, watchRepo) = makeSUT()
        await sut.toggle(coinId: "bitcoin")
        XCTAssertTrue(try watchRepo.isWatched(coinId: "bitcoin"))
        XCTAssertTrue(sut.isWatched(coinId: "bitcoin"))
    }

    func test_toggle_removesWhenAlreadyWatched() async {
        let (sut, _, watchRepo) = makeSUT(initiallyWatched: ["bitcoin"])
        await sut.refreshWatchedIds()
        await sut.toggle(coinId: "bitcoin")
        XCTAssertFalse(try watchRepo.isWatched(coinId: "bitcoin"))
        XCTAssertFalse(sut.isWatched(coinId: "bitcoin"))
    }
}
