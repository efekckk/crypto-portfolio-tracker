import XCTest
@testable import CryptoPortfolio

@MainActor
final class CoinDetailViewModelTests: XCTestCase {

    private func makeSUT(coin: Coin? = nil, points: [ChartPoint] = [], error: Error? = nil)
        -> (CoinDetailViewModel, MockCoinRepository) {
        let repo = MockCoinRepository()
        repo.marketsResult = coin.map { [$0] } ?? []
        repo.chartResult = points
        repo.errorToThrow = error
        let vm = CoinDetailViewModel(
            coinId: "bitcoin",
            currency: .usd,
            getCoinMarket: GetCoinMarketUseCase(coinRepository: repo),
            getCoinChart: GetCoinChartUseCase(coinRepository: repo)
        )
        return (vm, repo)
    }

    func test_initialState_bothLoading() {
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.headerState, .loading)
        XCTAssertEqual(sut.chartState, .loading)
        XCTAssertEqual(sut.selectedRange, .h24)
    }

    func test_loadAll_setsLoadedHeaderAndChart() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let points = [ChartPoint(id: 1, date: Date(timeIntervalSince1970: 0), price: 50_000)]
        let (sut, _) = makeSUT(coin: coin, points: points)

        await sut.loadAll()

        XCTAssertEqual(sut.headerState, .loaded(coin))
        if case .loaded(let pts) = sut.chartState {
            XCTAssertEqual(pts, points)
        } else {
            XCTFail("Expected chartState .loaded, got \(sut.chartState)")
        }
    }

    func test_loadAll_setsErrorOnNetworkFailure() async {
        let (sut, _) = makeSUT(error: APIError.rateLimited)
        await sut.loadAll()
        if case .error = sut.headerState { } else { XCTFail("Expected header .error") }
        if case .error = sut.chartState { } else { XCTFail("Expected chart .error") }
    }

    func test_loadHeader_setsErrorWhenCoinMissing() async {
        let (sut, _) = makeSUT(coin: nil, points: [])  // markets returns empty
        await sut.loadHeader()
        if case .error = sut.headerState { } else { XCTFail("Expected header .error for missing coin") }
    }

    func test_changeRange_updatesSelectedAndReloadsChart() async {
        let initialPoints = [ChartPoint(id: 1, date: Date(timeIntervalSince1970: 0), price: 50_000)]
        let (sut, repo) = makeSUT(coin: Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin"), points: initialPoints)
        await sut.loadAll()

        repo.chartResult = [ChartPoint(id: 2, date: Date(timeIntervalSince1970: 60), price: 51_000)]
        await sut.changeRange(to: .d30)

        XCTAssertEqual(sut.selectedRange, .d30)
        XCTAssertEqual(repo.lastChartRequest?.range, .d30)
        if case .loaded(let pts) = sut.chartState {
            XCTAssertEqual(pts.first?.price, 51_000)
        } else {
            XCTFail("Expected chart .loaded after range change")
        }
    }

    func test_changeRange_cancelsPreviousChartTask_andOnlyAppliesLatest() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let firstPoints = [ChartPoint(id: 1, date: Date(timeIntervalSince1970: 0), price: 100)]
        let secondPoints = [ChartPoint(id: 2, date: Date(timeIntervalSince1970: 60), price: 200)]
        let (sut, repo) = makeSUT(coin: coin, points: firstPoints)
        await sut.loadAll()

        // Trigger rapid range switches. Each `await` allows the task to run.
        repo.chartResult = firstPoints
        async let r1: Void = sut.changeRange(to: .d7)
        repo.chartResult = secondPoints
        async let r2: Void = sut.changeRange(to: .d30)
        _ = await (r1, r2)

        // Whatever ran last must win.
        XCTAssertEqual(sut.selectedRange, .d30)
        if case .loaded(let pts) = sut.chartState {
            XCTAssertEqual(pts.first?.price, 200, "Latest range request must apply")
        } else {
            XCTFail("Expected chart .loaded after final range change")
        }
    }

    func test_toggleWatchlist_addsAndThenRemoves_andUpdatesIsWatched() async {
        let watchRepo = MockWatchlistRepository()
        let coinRepo = MockCoinRepository()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        coinRepo.marketsResult = [coin]
        let vm = CoinDetailViewModel(
            coinId: "bitcoin",
            currency: .usd,
            getCoinMarket: GetCoinMarketUseCase(coinRepository: coinRepo),
            getCoinChart: GetCoinChartUseCase(coinRepository: coinRepo),
            toggleWatchlist: ToggleWatchlistUseCase(watchlistRepository: watchRepo),
            watchlistRepository: watchRepo
        )
        await vm.refreshIsWatched()
        XCTAssertFalse(vm.isWatched)

        await vm.toggleWatchlist()
        XCTAssertTrue(vm.isWatched)
        XCTAssertTrue(try watchRepo.isWatched(coinId: "bitcoin"))

        await vm.toggleWatchlist()
        XCTAssertFalse(vm.isWatched)
        XCTAssertFalse(try watchRepo.isWatched(coinId: "bitcoin"))
    }
}
