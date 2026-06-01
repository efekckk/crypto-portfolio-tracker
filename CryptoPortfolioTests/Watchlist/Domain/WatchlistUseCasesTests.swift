import XCTest
@testable import CryptoPortfolio

@MainActor
final class WatchlistUseCasesTests: XCTestCase {

    func test_toggle_addsWhenNotWatched() throws {
        let repo = MockWatchlistRepository()
        let sut = ToggleWatchlistUseCase(watchlistRepository: repo)

        try sut(coinId: "bitcoin")

        XCTAssertTrue(try repo.isWatched(coinId: "bitcoin"))
    }

    func test_toggle_removesWhenAlreadyWatched() throws {
        let repo = MockWatchlistRepository()
        try repo.add(coinId: "bitcoin")
        let sut = ToggleWatchlistUseCase(watchlistRepository: repo)

        try sut(coinId: "bitcoin")

        XCTAssertFalse(try repo.isWatched(coinId: "bitcoin"))
    }

    func test_getWatchlist_returnsEmptyWhenNoItems() async throws {
        let watchRepo = MockWatchlistRepository()
        let coinRepo = MockCoinRepository()
        let sut = GetWatchlistUseCase(watchlistRepository: watchRepo, coinRepository: coinRepo)

        let coins = try await sut(currency: .usd)

        XCTAssertTrue(coins.isEmpty)
    }

    func test_getWatchlist_fetchesMarketsForWatchedIds() async throws {
        let watchRepo = MockWatchlistRepository()
        try watchRepo.add(coinId: "bitcoin")
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50000)]
        let sut = GetWatchlistUseCase(watchlistRepository: watchRepo, coinRepository: coinRepo)

        let coins = try await sut(currency: .usd)

        XCTAssertEqual(coins.map(\.id), ["bitcoin"])
        XCTAssertEqual(coins.first?.currentPrice, 50000)
    }
}
