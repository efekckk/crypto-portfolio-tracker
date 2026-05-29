import SwiftUI

struct AddCoinView: View {
    @StateObject private var viewModel: AddCoinViewModel
    let onDone: (_ saved: Bool) -> Void

    init(searchCoins: SearchCoinsUseCase,
         addHolding: AddHoldingUseCase,
         onDone: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: AddCoinViewModel(
            searchCoins: searchCoins, addHolding: addHolding
        ))
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("addCoin.title")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("addCoin.search.prompt"))
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone(false) }
                    }
                }
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
                titleKey: "addCoin.empty.title",
                messageKey: "addCoin.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }
        case .loaded(let coins):
            List(coins) { coin in
                NavigationLink {
                    AmountEntryView(coin: coin, viewModel: viewModel) { saved in onDone(saved) }
                } label: {
                    SearchResultRow(coin: coin)
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct SearchResultRow: View {
    let coin: Coin
    var body: some View {
        HStack(spacing: 12) {
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
            VStack(alignment: .leading) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
