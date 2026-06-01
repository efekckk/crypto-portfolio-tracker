import SwiftUI

struct WatchlistView: View {
    @StateObject private var viewModel: WatchlistViewModel
    private let container: AppContainer
    @State private var isShowingAddSheet = false

    init(container: AppContainer, currency: Currency = .default) {
        self.container = container
        _viewModel = StateObject(wrappedValue: WatchlistViewModel(
            getWatchlist: container.makeGetWatchlistUseCase(),
            toggleWatchlist: container.makeToggleWatchlistUseCase(),
            currency: currency
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("watchlist.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.load() }
                .sheet(isPresented: $isShowingAddSheet) {
                    AddToWatchlistView(container: container) {
                        isShowingAddSheet = false
                        Task { await viewModel.load() }
                    }
                }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isShowingAddSheet = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("watchlist.addCoin.accessibility")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "star.slash",
                titleKey: "watchlist.empty.title",
                messageKey: "watchlist.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let coins):
            loadedList(coins: coins)
        }
    }

    private func loadedList(coins: [Coin]) -> some View {
        List {
            ForEach(coins) { coin in
                NavigationLink {
                    CoinDetailView(
                        coinId: coin.id,
                        coinName: coin.name,
                        currency: viewModel.currency,
                        container: container
                    )
                } label: {
                    WatchlistRow(coin: coin, currency: viewModel.currency)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.toggle(coinId: coin.id) }
                    } label: {
                        Label("watchlist.unwatch", systemImage: "star.slash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
