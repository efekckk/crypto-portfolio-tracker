import Foundation

@MainActor
final class CoinDetailViewModel: ObservableObject {
    @Published private(set) var headerState: ViewState<Coin> = .loading
    @Published private(set) var chartState: ViewState<[ChartPoint]> = .loading
    @Published private(set) var selectedRange: PriceRange = .h24

    let coinId: String
    let currency: Currency

    private let getCoinMarket: GetCoinMarketUseCase
    private let getCoinChart: GetCoinChartUseCase
    private var chartTask: Task<Void, Never>?

    init(coinId: String,
         currency: Currency,
         getCoinMarket: GetCoinMarketUseCase,
         getCoinChart: GetCoinChartUseCase) {
        self.coinId = coinId
        self.currency = currency
        self.getCoinMarket = getCoinMarket
        self.getCoinChart = getCoinChart
    }

    func loadAll() async {
        async let header: () = loadHeader()
        async let chart: () = loadChart()
        _ = await (header, chart)
    }

    func loadHeader() async {
        headerState = .loading
        do {
            if let coin = try await getCoinMarket(coinId: coinId, currency: currency) {
                headerState = .loaded(coin)
            } else {
                headerState = .error("Coin not found.")
            }
        } catch {
            headerState = .error(error.userFacingMessage)
        }
    }

    func loadChart() async {
        chartState = .loading
        do {
            let points = try await getCoinChart(coinId: coinId, range: selectedRange, currency: currency)
            chartState = .loaded(points)
        } catch {
            chartState = .error(error.userFacingMessage)
        }
    }

    func changeRange(to range: PriceRange) async {
        selectedRange = range
        chartTask?.cancel()
        let task = Task<Void, Never> { [weak self] in
            await self?.loadChart()
        }
        chartTask = task
        await task.value
    }
}
