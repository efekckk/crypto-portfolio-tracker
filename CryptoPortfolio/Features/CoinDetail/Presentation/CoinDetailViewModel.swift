import Foundation

@MainActor
final class CoinDetailViewModel: ObservableObject {
    @Published private(set) var headerState: ViewState<Coin> = .loading
    @Published private(set) var chartState: ViewState<[ChartPoint]> = .loading
    @Published private(set) var selectedRange: PriceRange = .h24
    @Published private(set) var isWatched: Bool = false

    let coinId: String
    let currency: Currency

    private let getCoinMarket: GetCoinMarketUseCase
    private let getCoinChart: GetCoinChartUseCase
    private let toggleWatchlistUseCase: ToggleWatchlistUseCase?
    private let watchlistRepository: WatchlistRepository?

    private var chartTask: Task<Void, Never>?

    init(coinId: String,
         currency: Currency,
         getCoinMarket: GetCoinMarketUseCase,
         getCoinChart: GetCoinChartUseCase,
         toggleWatchlist: ToggleWatchlistUseCase? = nil,
         watchlistRepository: WatchlistRepository? = nil) {
        self.coinId = coinId
        self.currency = currency
        self.getCoinMarket = getCoinMarket
        self.getCoinChart = getCoinChart
        self.toggleWatchlistUseCase = toggleWatchlist
        self.watchlistRepository = watchlistRepository
    }

    func loadAll() async {
        async let header: () = loadHeader()
        async let chart: () = loadChart()
        async let watch: () = refreshIsWatched()
        _ = await (header, chart, watch)
    }

    func loadHeader() async {
        headerState = .loading
        do {
            if let coin = try await getCoinMarket(coinId: coinId, currency: currency) {
                headerState = .loaded(coin)
            } else {
                headerState = .error(String(localized: "error.generic",
                                            defaultValue: "Something went wrong."))
            }
        } catch {
            headerState = .error(error.userFacingMessage)
        }
    }

    func loadChart() async {
        chartState = .loading
        do {
            let points = try await getCoinChart(coinId: coinId, range: selectedRange, currency: currency)
            // Don't apply stale results: if a newer changeRange call cancelled this
            // task, drop our write so the latest range wins deterministically.
            guard !Task.isCancelled else { return }
            chartState = .loaded(points)
        } catch {
            guard !Task.isCancelled else { return }
            chartState = .error(error.userFacingMessage)
        }
    }

    func changeRange(to range: PriceRange) async {
        selectedRange = range
        chartTask?.cancel()
        let task: Task<Void, Never> = Task { [weak self] in
            await self?.loadChart()
        }
        chartTask = task
        await task.value
    }

    func refreshIsWatched() async {
        guard let repo = watchlistRepository else { return }
        isWatched = (try? repo.isWatched(coinId: coinId)) ?? false
    }

    func toggleWatchlist() async {
        guard let useCase = toggleWatchlistUseCase else { return }
        try? useCase(coinId: coinId)
        await refreshIsWatched()
    }
}
