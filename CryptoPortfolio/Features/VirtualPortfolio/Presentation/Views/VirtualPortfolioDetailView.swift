import SwiftUI

/// Detail screen for a single virtual portfolio.
/// Shows the value/P&L header card, the holdings list, a navigation link to
/// trade history, and a toolbar for opening the trade flow and deleting.
struct VirtualPortfolioDetailView: View {
    @StateObject private var viewModel: VirtualPortfolioDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let api: VirtualPortfolioAPI
    private let container: AppContainer

    /// Transient sheet state for the coin picker and the resulting trade.
    @State private var isShowingCoinPicker = false
    @State private var selectedCoin: Coin?
    @State private var isShowingDeleteConfirmation = false

    init(portfolioID: UUID, api: VirtualPortfolioAPI, container: AppContainer) {
        _viewModel = StateObject(wrappedValue: VirtualPortfolioDetailViewModel(
            portfolioID: portfolioID,
            api: api
        ))
        self.api = api
        self.container = container
    }

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onChange(of: viewModel.wasDeleted) { deleted in
                if deleted { dismiss() }
            }
            .toolbar { toolbarContent }
            .sheet(isPresented: $isShowingCoinPicker) {
                VirtualCoinPickerSheet(container: container) { coin in
                    selectedCoin = coin
                }
            }
            .sheet(item: $selectedCoin) { coin in
                TradeSheet(
                    portfolioID: viewModel.portfolioID,
                    coinID: coin.id,
                    coinName: coin.name,
                    api: api
                ) { updatedPortfolio in
                    viewModel.applyPostTradeUpdate(updatedPortfolio)
                }
            }
            .confirmationDialog(
                String(localized: "virtual.detail.delete.confirm.title",
                       defaultValue: "Delete this portfolio?"),
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    String(localized: "common.delete", defaultValue: "Delete"),
                    role: .destructive
                ) {
                    Task { await viewModel.delete() }
                }
                Button(
                    String(localized: "common.cancel", defaultValue: "Cancel"),
                    role: .cancel
                ) {}
            } message: {
                Text(String(localized: "virtual.detail.delete.confirm.message",
                            defaultValue: "All trades and holdings will be permanently removed."))
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            EmptyStateView(
                systemImage: "briefcase",
                titleKey: "virtual.detail.empty.title",
                messageKey: "virtual.detail.empty.message"
            )

        case .error(let message):
            VStack {
                if let lastErr = viewModel.lastError {
                    Text(lastErr)
                        .foregroundStyle(Theme.negative)
                        .font(.subheadline)
                        .padding(.horizontal)
                }
                ErrorStateView(message: message) { Task { await viewModel.load() } }
            }

        case .loaded(let portfolio):
            portfolioBody(portfolio)
        }
    }

    @ViewBuilder
    private func portfolioBody(_ portfolio: VirtualPortfolio) -> some View {
        List {
            // Header card
            Section {
                HeaderCard(portfolio: portfolio)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Holdings
            if !portfolio.holdings.isEmpty {
                Section {
                    ForEach(portfolio.holdings) { holding in
                        VirtualHoldingRow(holding: holding)
                    }
                } header: {
                    Text(String(localized: "virtual.detail.holdings.header",
                                defaultValue: "Holdings"))
                }
            }

            // Trade history link
            Section {
                NavigationLink {
                    VirtualTradeHistoryView(
                        portfolioID: portfolio.id,
                        api: api
                    )
                } label: {
                    Label(
                        String(localized: "virtual.detail.history.link",
                               defaultValue: "Trade History"),
                        systemImage: "clock.arrow.2.circlepath"
                    )
                }
            }

            // Inline error banner (non-fatal, e.g. delete failed)
            if let lastErr = viewModel.lastError {
                Section {
                    Text(lastErr)
                        .foregroundStyle(Theme.negative)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle(portfolio.name)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    isShowingCoinPicker = true
                } label: {
                    Label(
                        String(localized: "virtual.detail.toolbar.trade",
                               defaultValue: "Trade"),
                        systemImage: "plus"
                    )
                }

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label(
                        String(localized: "virtual.detail.toolbar.delete",
                               defaultValue: "Delete portfolio"),
                        systemImage: "trash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Header Card

private struct HeaderCard: View {
    let portfolio: VirtualPortfolio

    private var totalPnL: Double {
        portfolio.realizedPnL + portfolio.unrealizedPnL
    }

    var body: some View {
        VStack(spacing: 16) {
            // Total value — hero number
            VStack(spacing: 4) {
                Text(String(localized: "virtual.detail.card.totalValue",
                            defaultValue: "Total Value"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(portfolio.totalValue, currency: .usd))
                    .font(.title.weight(.bold))

                Text(CurrencyFormatter.formatPercent(portfolio.totalPnLPercent))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.color(forChange: portfolio.totalPnLPercent))
            }

            Divider()

            // Stats grid
            HStack {
                StatCell(
                    label: String(localized: "virtual.detail.card.starting",
                                  defaultValue: "Starting"),
                    value: CurrencyFormatter.format(portfolio.startingBalance, currency: .usd),
                    color: .primary
                )
                Divider().frame(height: 36)
                StatCell(
                    label: String(localized: "virtual.detail.card.cash",
                                  defaultValue: "Cash"),
                    value: CurrencyFormatter.format(portfolio.cashBalance, currency: .usd),
                    color: .primary
                )
                Divider().frame(height: 36)
                StatCell(
                    label: String(localized: "virtual.detail.card.realized",
                                  defaultValue: "Realized"),
                    value: CurrencyFormatter.format(portfolio.realizedPnL, currency: .usd),
                    color: Theme.color(forChange: portfolio.realizedPnL)
                )
                Divider().frame(height: 36)
                StatCell(
                    label: String(localized: "virtual.detail.card.unrealized",
                                  defaultValue: "Unrealized"),
                    value: CurrencyFormatter.format(portfolio.unrealizedPnL, currency: .usd),
                    color: Theme.color(forChange: portfolio.unrealizedPnL)
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(16)
    }
}

private struct StatCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Holding Row

private struct VirtualHoldingRow: View {
    let holding: VirtualHolding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(holding.coinId.uppercased())
                    .font(.body.weight(.semibold))
                Spacer()
                if let value = holding.currentValue {
                    Text(CurrencyFormatter.format(value, currency: .usd))
                        .font(.body.weight(.semibold))
                } else {
                    Text(String(localized: "virtual.detail.holding.na", defaultValue: "n/a"))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                amountLabel
                Spacer()
                pnlLabel
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var amountLabel: some View {
        Group {
            let amtStr = formatAmount(holding.amount)
            let avgStr = CurrencyFormatter.format(holding.averageBuyPrice, currency: .usd)
            Text("\(amtStr) @ \(avgStr)")
        }
    }

    @ViewBuilder
    private var pnlLabel: some View {
        if let pnl = holding.unrealizedPnL, let pnlPct = holding.unrealizedPnLPercent {
            HStack(spacing: 4) {
                Text(CurrencyFormatter.format(pnl, currency: .usd))
                    .foregroundStyle(Theme.color(forChange: pnl))
                Text(CurrencyFormatter.formatPercent(pnlPct))
                    .foregroundStyle(Theme.color(forChange: pnlPct))
            }
        } else {
            Text(String(localized: "virtual.detail.holding.na", defaultValue: "n/a"))
        }
    }

    private func formatAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        f.numberStyle = .decimal
        f.decimalSeparator = "."
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
}
