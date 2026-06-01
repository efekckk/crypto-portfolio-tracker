import SwiftUI

struct CoinDetailView: View {
    @StateObject private var viewModel: CoinDetailViewModel
    let coinName: String
    private let container: AppContainer

    @State private var addingHolding: Coin?
    @State private var creatingAlertFor: Coin?

    init(coinId: String,
         coinName: String,
         currency: Currency,
         container: AppContainer) {
        self.coinName = coinName
        self.container = container
        _viewModel = StateObject(wrappedValue: CoinDetailViewModel(
            coinId: coinId,
            currency: currency,
            getCoinMarket: container.makeGetCoinMarketUseCase(),
            getCoinChart: container.makeGetCoinChartUseCase(),
            toggleWatchlist: container.makeToggleWatchlistUseCase(),
            watchlistRepository: container.watchlistRepository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                quickActions
                rangeAndChartSection
                statsSection
            }
            .padding()
        }
        .navigationTitle(coinName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAll() }
        .sheet(item: $addingHolding) { coin in
            NavigationStack {
                AmountEntryView(
                    coin: coin,
                    viewModel: AddCoinViewModel(
                        searchCoins: container.makeSearchCoinsUseCase(),
                        addHolding: container.makeAddHoldingUseCase()
                    )
                ) { _ in addingHolding = nil }
            }
        }
        .sheet(item: $creatingAlertFor) { _ in
            CreateAlertView(container: container) { _ in
                creatingAlertFor = nil
            }
        }
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

    @ViewBuilder
    private var quickActions: some View {
        if case .loaded(let coin) = viewModel.headerState {
            HStack(spacing: 12) {
                Button {
                    addingHolding = coin
                } label: {
                    Label("coinDetail.action.addToPortfolio", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    Task { await viewModel.toggleWatchlist() }
                } label: {
                    Label(viewModel.isWatched ? "coinDetail.action.watchlistRemove"
                                              : "coinDetail.action.watchlistAdd",
                          systemImage: viewModel.isWatched ? "star.slash.fill" : "star.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isWatched ? .secondary : Theme.accent)

                Button {
                    creatingAlertFor = coin
                } label: {
                    Label("coinDetail.action.createAlert", systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.medium))
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
