import SwiftUI

struct CoinDetailView: View {
    @StateObject private var viewModel: CoinDetailViewModel
    let coinName: String

    init(coinId: String,
         coinName: String,
         currency: Currency,
         container: AppContainer) {
        _viewModel = StateObject(wrappedValue: CoinDetailViewModel(
            coinId: coinId, currency: currency,
            getCoinMarket: container.makeGetCoinMarketUseCase(),
            getCoinChart: container.makeGetCoinChartUseCase()
        ))
        self.coinName = coinName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                rangeAndChartSection
                statsSection
            }
            .padding()
        }
        .navigationTitle(coinName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAll() }
    }

    @ViewBuilder
    private var headerSection: some View {
        switch viewModel.headerState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .empty:
            EmptyView()
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.loadHeader() } }
                .frame(minHeight: 120)
        case .loaded(let coin):
            CoinDetailHeaderView(coin: coin, currency: viewModel.currency)
        }
    }

    private var rangeAndChartSection: some View {
        VStack(spacing: 12) {
            RangeSelector(
                selection: Binding(
                    get: { viewModel.selectedRange },
                    set: { newValue in Task { await viewModel.changeRange(to: newValue) } }
                )
            )
            chartContent
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        switch viewModel.chartState {
        case .loading:
            ProgressView().frame(height: 220)
        case .empty:
            Text("—").foregroundStyle(.secondary).frame(height: 220)
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.loadChart() } }
                .frame(minHeight: 220)
        case .loaded(let points):
            PriceChartView(points: points)
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if case .loaded(let coin) = viewModel.headerState {
            VStack(alignment: .leading, spacing: 8) {
                Text("coinDetail.stats.title")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                CoinStatsView(coin: coin, currency: viewModel.currency)
            }
        }
    }
}
