import SwiftUI

/// Pushed view showing the paginated trade history for a virtual portfolio.
struct VirtualTradeHistoryView: View {
    @StateObject private var viewModel: TradeHistoryViewModel

    init(portfolioID: UUID, api: VirtualPortfolioAPI) {
        _viewModel = StateObject(wrappedValue: TradeHistoryViewModel(
            portfolioID: portfolioID,
            api: api
        ))
    }

    var body: some View {
        content
            .navigationTitle(
                String(localized: "virtual.history.title", defaultValue: "Trade History")
            )
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            EmptyStateView(
                systemImage: "clock.arrow.2.circlepath",
                titleKey: "virtual.history.empty.title",
                messageKey: "virtual.history.empty.message"
            )

        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }

        case .loaded(let trades):
            List {
                ForEach(trades) { trade in
                    TradeHistoryRow(trade: trade)
                }

                if viewModel.hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .task { await viewModel.loadMore() }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Row

private struct TradeHistoryRow: View {
    let trade: VirtualTrade

    var body: some View {
        HStack(spacing: 12) {
            SideBadge(side: trade.side)

            VStack(alignment: .leading, spacing: 3) {
                Text(trade.coinId.uppercased())
                    .font(.body.weight(.semibold))
                Text(amountByPrice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(trade.executedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private var amountByPrice: String {
        let amt = formatAmount(trade.amount)
        let price = CurrencyFormatter.format(trade.price, currency: .usd)
        return "\(amt) × \(price)"
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

// MARK: - Side badge

private struct SideBadge: View {
    let side: VirtualTrade.Side

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor, in: Capsule())
    }

    private var label: String {
        switch side {
        case .buy:
            return String(localized: "virtual.history.side.buy", defaultValue: "BUY")
        case .sell:
            return String(localized: "virtual.history.side.sell", defaultValue: "SELL")
        }
    }

    private var badgeColor: Color {
        switch side {
        case .buy: return Theme.positive
        case .sell: return Theme.negative
        }
    }
}
