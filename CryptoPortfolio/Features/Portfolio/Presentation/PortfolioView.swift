import SwiftUI

struct PortfolioView: View {
    @StateObject private var viewModel: PortfolioViewModel
    @Environment(\.appContainer) private var container
    @State private var isShowingAddCoin = false

    init(getSummary: GetPortfolioSummaryUseCase,
         removeHolding: RemoveHoldingUseCase,
         currency: Currency = .default) {
        _viewModel = StateObject(wrappedValue: PortfolioViewModel(
            getSummary: getSummary, removeHolding: removeHolding, currency: currency
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
                    HoldingRow(valuation: item, currency: viewModel.currency)
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
        AddCoinView(
            searchCoins: container.makeSearchCoinsUseCase(),
            addHolding: container.makeAddHoldingUseCase()
        ) { saved in
            isShowingAddCoin = false
            if saved { Task { await viewModel.load() } }
        }
    }
}
