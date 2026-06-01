import SwiftUI

struct PortfolioView: View {
    @StateObject private var viewModel: PortfolioViewModel
    private let container: AppContainer
    @State private var isShowingAddCoin = false
    @State private var sharingCode: PortfolioShareCode?

    init(container: AppContainer, currency: Currency = .default) {
        self.container = container
        _viewModel = StateObject(wrappedValue: PortfolioViewModel(
            getSummary: container.makeGetPortfolioSummaryUseCase(),
            removeHolding: container.makeRemoveHoldingUseCase(),
            currency: currency
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("portfolio.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.load() }
                .sheet(isPresented: $isShowingAddCoin) { addCoinSheet }
                .sheet(item: $sharingCode) { code in
                    ShareQRView(code: code, coinName: code.coinId.capitalized)
                }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isShowingAddCoin = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("portfolio.addCoin.accessibility")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "chart.pie",
                titleKey: "portfolio.empty.title",
                messageKey: "portfolio.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let summary):
            loadedList(summary: summary)
        }
    }

    private func loadedList(summary: PortfolioSummary) -> some View {
        List {
            Section { PortfolioSummaryHeader(summary: summary, currency: viewModel.currency) }
            Section("portfolio.holdings.section") {
                ForEach(summary.items) { item in
                    NavigationLink {
                        CoinDetailView(
                            coinId: item.holding.coinId,
                            coinName: item.coin?.name ?? item.holding.coinId.capitalized,
                            currency: viewModel.currency,
                            container: container
                        )
                    } label: {
                        HoldingRow(valuation: item, currency: viewModel.currency)
                    }
                    .contextMenu {
                        Button {
                            sharingCode = PortfolioShareCode(coinId: item.holding.coinId, amount: item.holding.amount)
                        } label: {
                            Label("portfolio.shareQR", systemImage: "qrcode")
                        }
                    }
                }
                .onDelete { indices in
                    let ids = indices.map { summary.items[$0].holding.coinId }
                    Task { for id in ids { await viewModel.delete(coinId: id) } }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var addCoinSheet: some View {
        AddCoinView(container: container) { saved in
            isShowingAddCoin = false
            if saved { Task { await viewModel.load() } }
        }
    }
}
