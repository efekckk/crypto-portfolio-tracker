import Foundation

/// Backs the buy/sell trade sheet for a single coin in a single portfolio.
///
/// The sheet opens with a coin already chosen (from CoinSearchPickerView).
/// The VM fetches a fresh quote on appear, lets the user flip side, edit
/// the amount, or tap "Max" (which fills the side-appropriate cap from the
/// quote), then submits via `confirm()`. `confirm` returns the post-trade
/// portfolio snapshot so the caller can hand it straight to the detail VM.
@MainActor
final class TradeViewModel: ObservableObject {
    @Published var side: VirtualTrade.Side = .buy {
        didSet { totalCost = computeTotalCost() }
    }
    @Published var amountText: String = "" {
        didSet { totalCost = computeTotalCost() }
    }
    @Published private(set) var quoteState: ViewState<VirtualQuote> = .loading
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var saveError: String?

    /// USD cost (or proceeds) implied by the current amount × current quote
    /// price. Empty when either is missing.
    @Published private(set) var totalCost: Double?

    let portfolioID: UUID
    let coinID: String
    let coinName: String

    private let api: VirtualPortfolioAPI

    init(portfolioID: UUID, coinID: String, coinName: String, api: VirtualPortfolioAPI) {
        self.portfolioID = portfolioID
        self.coinID = coinID
        self.coinName = coinName
        self.api = api
    }

    // MARK: - Quote

    /// Fetches a fresh quote. Called on appear and after the user flips side.
    func refreshQuote() async {
        quoteState = .loading
        do {
            let quote = try await api.quote(portfolioID: portfolioID, coinID: coinID)
            quoteState = .loaded(quote)
            totalCost = computeTotalCost()
        } catch let error as VirtualAPIError {
            quoteState = .error(error.userFacingMessage)
        } catch {
            quoteState = .error(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Fills `amountText` with the side-appropriate cap from the quote.
    func setMaxAmount() {
        guard case .loaded(let quote) = quoteState else { return }
        let max: Double
        switch side {
        case .buy: max = quote.maxBuyAmount
        case .sell: max = quote.maxSellAmount
        }
        amountText = formatAmount(max)
    }

    /// True when the user has typed a valid positive number that doesn't
    /// exceed the side-appropriate cap. UI uses this to enable the Confirm
    /// button.
    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard case .loaded(let quote) = quoteState else { return false }
        guard let amount = parsedAmount, amount > 0 else { return false }
        switch side {
        case .buy: return amount <= quote.maxBuyAmount + 1e-9
        case .sell: return amount <= quote.maxSellAmount + 1e-9
        }
    }

    /// Numeric form of `amountText`, comma-decimal normalised.
    private var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return nil }
        return value
    }

    private func computeTotalCost() -> Double? {
        guard case .loaded(let quote) = quoteState, let amount = parsedAmount else { return nil }
        return amount * quote.price
    }

    private func formatAmount(_ value: Double) -> String {
        // Show up to 8 fraction digits (matches typical crypto precision), trim trailing zeros.
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        f.numberStyle = .decimal
        f.decimalSeparator = "."
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: - Submit

    /// Submits the trade. Returns the post-trade portfolio snapshot on
    /// success; nil on failure (`saveError` will be populated).
    func confirm() async -> VirtualPortfolio? {
        guard !isSubmitting else { return nil }
        guard let amount = parsedAmount, amount > 0 else {
            saveError = String(localized: "virtual.trade.error.invalid_amount",
                               defaultValue: "Enter a positive amount.")
            return nil
        }
        isSubmitting = true
        saveError = nil
        defer { isSubmitting = false }

        do {
            let portfolio = try await api.executeTrade(portfolioID: portfolioID,
                                                       side: side,
                                                       coinID: coinID,
                                                       amount: amount)
            return portfolio
        } catch let error as VirtualAPIError {
            saveError = mapTradeError(error)
            return nil
        } catch {
            saveError = error.localizedDescription
            return nil
        }
    }

    /// Trade-specific error mapping. Insufficient-cash / insufficient-holdings
    /// surface dedicated strings the trade sheet renders in place. Everything
    /// else falls through to the generic VirtualAPIError mapping.
    private func mapTradeError(_ error: VirtualAPIError) -> String {
        if case .unprocessable(let detail) = error {
            switch detail {
            case "insufficient_cash":
                return String(localized: "virtual.trade.error.insufficient_cash",
                              defaultValue: "Not enough cash for this trade.")
            case "insufficient_holdings":
                return String(localized: "virtual.trade.error.insufficient_holdings",
                              defaultValue: "Not enough holdings to sell.")
            default:
                break
            }
        }
        return error.userFacingMessage
    }
}
