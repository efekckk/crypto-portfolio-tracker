import SwiftUI

/// Buy/sell sheet for a single coin in a virtual portfolio.
/// On a successful trade, `onTraded` delivers the post-trade portfolio
/// snapshot to the caller (which hands it to `VirtualPortfolioDetailViewModel
/// .applyPostTradeUpdate(_:)`) and the sheet dismisses.
struct TradeSheet: View {
    @StateObject private var viewModel: TradeViewModel
    @Environment(\.dismiss) private var dismiss

    let onTraded: (VirtualPortfolio) -> Void

    init(
        portfolioID: UUID,
        coinID: String,
        coinName: String,
        api: VirtualPortfolioAPI,
        onTraded: @escaping (VirtualPortfolio) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TradeViewModel(
            portfolioID: portfolioID,
            coinID: coinID,
            coinName: coinName,
            api: api
        ))
        self.onTraded = onTraded
    }

    var body: some View {
        NavigationStack {
            Form {
                sideSection
                amountSection
                quoteSection

                if let error = viewModel.saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(Theme.negative)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task { await handleConfirm() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSubmitting {
                                ProgressView()
                            } else {
                                Text(String(localized: "common.confirm",
                                            defaultValue: "Confirm"))
                                    .font(.body.weight(.semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .navigationTitle(viewModel.coinName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        String(localized: "common.cancel", defaultValue: "Cancel")
                    ) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refreshQuote() }
                    } label: {
                        Label(
                            String(localized: "virtual.trade.refresh.button",
                                   defaultValue: "Refresh quote"),
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
            }
            .task { await viewModel.refreshQuote() }
            .refreshable { await viewModel.refreshQuote() }
        }
    }

    // MARK: - Sections

    private var sideSection: some View {
        Section {
            Picker(
                String(localized: "virtual.trade.side.label", defaultValue: "Side"),
                selection: $viewModel.side
            ) {
                Text(String(localized: "virtual.trade.side.buy", defaultValue: "Buy"))
                    .tag(VirtualTrade.Side.buy)
                Text(String(localized: "virtual.trade.side.sell", defaultValue: "Sell"))
                    .tag(VirtualTrade.Side.sell)
            }
            .pickerStyle(.segmented)
        }
    }

    private var amountSection: some View {
        Section {
            HStack {
                TextField(
                    String(localized: "virtual.trade.amount.placeholder",
                           defaultValue: "Amount"),
                    text: $viewModel.amountText
                )
                .keyboardType(.decimalPad)

                Button(
                    String(localized: "virtual.trade.max.button", defaultValue: "Max")
                ) {
                    viewModel.setMaxAmount()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
            }

            if let total = viewModel.totalCost {
                HStack {
                    Text(String(localized: "virtual.trade.total.label",
                                defaultValue: "Total"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatter.format(total, currency: .usd))
                        .font(.body.weight(.semibold))
                }
            }
        } header: {
            Text(String(localized: "virtual.trade.amount.header", defaultValue: "AMOUNT"))
        }
    }

    @ViewBuilder
    private var quoteSection: some View {
        switch viewModel.quoteState {
        case .loading:
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } header: {
                Text(String(localized: "virtual.trade.quote.header", defaultValue: "QUOTE"))
            }

        case .loaded(let quote):
            Section {
                LabeledContent(
                    String(localized: "virtual.trade.quote.price", defaultValue: "Price"),
                    value: CurrencyFormatter.format(quote.price, currency: .usd)
                )
                LabeledContent(
                    String(localized: "virtual.trade.quote.maxBuy", defaultValue: "Max buy"),
                    value: "\(formatAmount(quote.maxBuyAmount)) \(viewModel.coinID.uppercased())"
                )
                LabeledContent(
                    String(localized: "virtual.trade.quote.maxSell", defaultValue: "Max sell"),
                    value: "\(formatAmount(quote.maxSellAmount)) \(viewModel.coinID.uppercased())"
                )
                Text(
                    String(
                        localized: "virtual.trade.quote.fetchedAt",
                        defaultValue: "Fetched at \(quote.fetchedAt.formatted(date: .omitted, time: .shortened))"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "virtual.trade.quote.header", defaultValue: "QUOTE"))
            }

        case .error(let message):
            Section {
                Text(message)
                    .foregroundStyle(Theme.negative)
                    .font(.subheadline)
            } header: {
                Text(String(localized: "virtual.trade.quote.header", defaultValue: "QUOTE"))
            }

        case .empty:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func handleConfirm() async {
        guard let portfolio = await viewModel.confirm() else { return }
        onTraded(portfolio)
        dismiss()
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
