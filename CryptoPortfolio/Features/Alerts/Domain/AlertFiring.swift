import Foundation

/// An alert that crossed its threshold during evaluation.
struct AlertFiring: Equatable {
    let alert: PriceAlert
    let firedAt: Date
    /// The measured value that satisfied the condition. Meaning depends on the
    /// variant: current price for `.priceCrossing`, percent change for
    /// `.percentChange`, total value for `.portfolioValue`, P/L percent for
    /// `.portfolioPnLPercent`. `nil` only if the data needed to compute it was
    /// missing in the same pass (shouldn't normally happen — if the alert fired
    /// the value existed).
    let actualValue: Double?
    /// Human-presentable coin name for coin-bound variants, resolved from the
    /// markets fetch performed during evaluation. `nil` for portfolio variants
    /// or when the coin wasn't in the markets response.
    let coinName: String?

    init(alert: PriceAlert,
         firedAt: Date,
         actualValue: Double? = nil,
         coinName: String? = nil) {
        self.alert = alert
        self.firedAt = firedAt
        self.actualValue = actualValue
        self.coinName = coinName
    }
}
