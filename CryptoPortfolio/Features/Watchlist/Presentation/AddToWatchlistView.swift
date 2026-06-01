import SwiftUI

struct AddToWatchlistView: View {
    @StateObject private var viewModel: AddToWatchlistViewModel
    let onDone: () -> Void

    init(container: AppContainer, onDone: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AddToWatchlistViewModel(
            searchCoins: container.makeSearchCoinsUseCase(),
            toggleWatchlist: container.makeToggleWatchlistUseCase(),
            watchlistRepository: container.watchlistRepository
        ))
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("watchlist.addCoin.title")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("watchlist.search.prompt"))
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone() }
                    }
                }
                .task { await viewModel.refreshWatchedIds() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.results {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "magnifyingglass",
                titleKey: "watchlist.add.empty.title",
                messageKey: "watchlist.add.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }
        case .loaded(let coins):
            List(coins) { coin in
                Button {
                    Task { await viewModel.toggle(coinId: coin.id) }
                } label: {
                    AddToWatchlistRow(coin: coin, isWatched: viewModel.isWatched(coinId: coin.id))
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}

private struct AddToWatchlistRow: View {
    let coin: Coin
    let isWatched: Bool

    var body: some View {
        HStack(spacing: 12) {
            coinImage
            VStack(alignment: .leading) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isWatched ? "star.fill" : "star")
                .foregroundStyle(isWatched ? Theme.accent : .secondary)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var coinImage: some View {
        if let url = coin.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                default: Circle().fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            Circle().fill(.secondary.opacity(0.2)).frame(width: 32, height: 32)
        }
    }
}
