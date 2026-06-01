import SwiftUI

struct CreateAlertView: View {
    @StateObject private var viewModel: CreateAlertViewModel
    private let initialCoin: Coin?
    let onDone: (_ didCreate: Bool) -> Void

    @State private var directRoute: Coin?

    init(container: AppContainer, initialCoin: Coin? = nil, onDone: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreateAlertViewModel(
            searchCoins: container.makeSearchCoinsUseCase(),
            createAlert: container.makeCreateAlertUseCase()
        ))
        self.initialCoin = initialCoin
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("alerts.create.searchTitle")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("alerts.create.search.prompt"))
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone(false) }
                    }
                }
                .background(
                    NavigationLink(
                        isActive: Binding(
                            get: { directRoute != nil },
                            set: { if !$0 { directRoute = nil } }
                        )
                    ) {
                        if let coin = directRoute {
                            AlertConditionView(coin: coin, viewModel: viewModel) { saved in onDone(saved) }
                        }
                    } label: { EmptyView() }
                    .hidden()
                )
                .task {
                    if let coin = initialCoin, directRoute == nil {
                        directRoute = coin
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
                titleKey: "alerts.create.empty.title",
                messageKey: "alerts.create.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }
        case .loaded(let coins):
            List(coins) { coin in
                NavigationLink {
                    AlertConditionView(coin: coin, viewModel: viewModel) { saved in onDone(saved) }
                } label: {
                    coinRow(coin)
                }
            }
            .listStyle(.plain)
        }
    }

    private func coinRow(_ coin: Coin) -> some View {
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
