import Foundation

/// Single source of truth for the title/body strings shown to the user when
/// an alert fires. Used by both `AppContainer.evaluateAndNotify` (foreground +
/// BGTask path) and any in-app surfaces that want to echo the same wording.
enum AlertNotificationFormatter {

    static func title(for firing: AlertFiring) -> String {
        // Neutral title so portfolio-variant firings aren't mis-titled
        // "Price alert". The body carries the variant-specific detail.
        String(localized: "alerts.notification.title", defaultValue: "Alert")
    }

    static func body(for firing: AlertFiring,
                     coinName: String?,
                     currency: Currency) -> String {
        switch firing.alert.condition {
        case .priceCrossing(let coinId, _, let targetPrice):
            let name = coinName ?? coinId.capitalized
            let price = CurrencyFormatter.format(targetPrice, currency: currency)
            return String(
                format: String(localized: "alerts.notification.body.priceCrossing",
                               defaultValue: "%@ crossed %@"),
                name, price
            )

        case .percentChange(let coinId, _, let window, let threshold):
            // We don't carry the actual percent move through AlertFiring, so
            // the body names the threshold the move crossed rather than
            // claiming the move equals it.
            let name = coinName ?? coinId.capitalized
            let percent = Self.formatPercent(threshold)
            let windowLabel = Self.windowLabel(window)
            return String(
                format: String(localized: "alerts.notification.body.percentChange",
                               defaultValue: "%@ crossed %@ in %@"),
                name, percent, windowLabel
            )

        case .portfolioValue(_, let threshold):
            let amount = CurrencyFormatter.format(threshold, currency: currency)
            return String(
                format: String(localized: "alerts.notification.body.portfolioValue",
                               defaultValue: "Portfolio total reached %@"),
                amount
            )

        case .portfolioPnLPercent(_, let threshold):
            let percent = Self.formatPercent(threshold)
            return String(
                format: String(localized: "alerts.notification.body.portfolioPnLPercent",
                               defaultValue: "Portfolio P/L is now %@"),
                percent
            )
        }
    }

    private static func formatPercent(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        let n = nf.string(from: NSNumber(value: value)) ?? String(value)
        return "\(n)%"
    }

    private static func windowLabel(_ window: AlertCondition.PercentWindow) -> String {
        switch window {
        case .h24: return String(localized: "alerts.window.h24", defaultValue: "24h")
        case .d7:  return String(localized: "alerts.window.d7",  defaultValue: "7d")
        case .d30: return String(localized: "alerts.window.d30", defaultValue: "30d")
        }
    }
}
