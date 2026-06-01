import SwiftUI

struct AddCoinView: View {
    @StateObject private var viewModel: AddCoinViewModel
    let onDone: (_ saved: Bool) -> Void

    @State private var isShowingScanner = false
    @State private var scannedCode: PortfolioShareCode?

    init(container: AppContainer, onDone: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: AddCoinViewModel(
            searchCoins: container.makeSearchCoinsUseCase(),
            addHolding: container.makeAddHoldingUseCase()
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
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isShowingScanner = true } label: {
                            Label("addCoin.scanQR.button", systemImage: "qrcode.viewfinder")
                        }
                    }
                }
                .sheet(isPresented: $isShowingScanner) {
                    ScanQRSheet(
                        onCodeDetected: { code in
                            isShowingScanner = false
                            // Defer to the next runloop so the dismiss completes before
                            // SwiftUI sees the new sheet trigger (iOS 16 swallows otherwise).
                            Task { @MainActor in scannedCode = code }
                        },
                        onCancel: { isShowingScanner = false }
                    )
                }
                .sheet(item: $scannedCode) { code in
                    NavigationStack {
                        AmountEntryView(
                            coin: Coin(id: code.coinId, symbol: code.coinId, name: code.coinId.capitalized),
                            viewModel: viewModel,
                            prefillAmount: code.amount
                        ) { saved in
                            scannedCode = nil
                            if saved { onDone(true) }
                        }
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
