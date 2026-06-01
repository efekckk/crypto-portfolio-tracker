import XCTest
@testable import CryptoPortfolio

@MainActor
final class WatchlistViewModelTests: XCTestCase {

    private func makeSUT(watched: [String] = [], coins: [Coin] = [], error: Error? = nil)
        -> (WatchlistViewModel, MockWatchlistRepository, MockCoinRepository) {
        let watchRepo = MockWatchlistRepository()
        for id in watched { try? watchRepo.add(coinId: id) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        coinRepo.errorToThrow = error
        let vm = WatchlistViewModel(
            getWatchlist: GetWatchlistUseCase(watchlistRepository: watchRepo, coinRepository: coinRepo),
            toggleWatchlist: ToggleWatchlistUseCase(watchlistRepository: watchRepo),
            currency: .usd
        )
        return (vm, watchRepo, coinRepo)
    }

    func test_initialState_isLoading() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.state, .loading)
    }

    func test_load_setsEmptyForNoWatchedItems() async {
        let (sut, _, _) = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_load_setsLoadedWithCoins() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, _, _) = makeSUT(watched: ["bitcoin"], coins: [coin])

        await sut.load()

        XCTAssertEqual(sut.state, .loaded([coin]))
    }

    func test_load_setsErrorOnNetworkFailure() async {
        let (sut, _, _) = makeSUT(watched: ["bitcoin"], coins: [], error: APIError.rateLimited)
        await sut.load()
        if case .error = sut.state { } else { XCTFail("Expected .error") }
    }

    func test_toggle_removesWatchedAndReloads() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, watchRepo, _) = makeSUT(watched: ["bitcoin"], coins: [coin])
        await sut.load()

        await sut.toggle(coinId: "bitcoin")

        XCTAssertFalse(try watchRepo.isWatched(coinId: "bitcoin"))
        XCTAssertEqual(sut.state, .empty)
    }
}
