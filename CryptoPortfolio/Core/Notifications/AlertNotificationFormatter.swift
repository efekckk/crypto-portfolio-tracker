import Foundation

/// Single source of truth for the title/body strings shown to the user when
/// an alert fires. Uses the measured value carried on `AlertFiring` when
/// available so the body reports what actually happened, not just the
/// threshold that was crossed.
enum AlertNotificationFormatter {

    static func title(for firing: AlertFiring) -> String {
        // Neutral title so portfolio-variant firings aren't mis-titled
        // "Price alert". The body carries the variant-specific detail.
        String(localized: "alerts.notification.title", defaultValue: "Alert")
    }

    static func body(for firing: AlertFiring, currency: Currency) -> String {
        switch firing.alert.condition {
        case .priceCrossing(let coinId, _, let targetPrice):
            let name = firing.coinName ?? coinId.capitalized
            if let measured = firing.actualValue {
                return String(
                    format: String(localized: "alerts.notification.body.priceCrossing.withActual",
                                   defaultValue: "%@ reached %@"),
                    name, CurrencyFormatter.format(measured, currency: currency)
                )
            }
            return String(
                format: String(localized: "alerts.notification.body.priceCrossing",
                               defaultValue: "%@ crossed %@"),
                name, CurrencyFormatter.format(targetPrice, currency: currency)
            )

        case .percentChange(let coinId, _, let window, let threshold):
            let name = firing.coinName ?? coinId.capitalized
            let windowLabel = Self.windowLabel(window)
            if let measured = firing.actualValue {
                return String(
                    format: String(localized: "alerts.notification.body.percentChange.withActual",
                                   defaultValue: "%@ moved %@ in %@"),
                    name, Self.formatPercent(measured), windowLabel
                )
            }
            return String(
                format: String(localized: "alerts.notification.body.percentChange",
                               defaultValue: "%@ crossed %@ in %@"),
                name, Self.formatPercent(threshold), windowLabel
            )

        case .portfolioValue(_, let threshold):
            // Same template either way; just pass actual or threshold.
            let amount = firing.actualValue ?? threshold
            return String(
                format: String(localized: "alerts.notification.body.portfolioValue",
                               defaultValue: "Portfolio total reached %@"),
                CurrencyFormatter.format(amount, currency: currency)
            )

        case .portfolioPnLPercent(_, let threshold):
            let percent = firing.actualValue ?? threshold
            return String(
                format: String(localized: "alerts.notification.body.portfolioPnLPercent",
                               defaultValue: "Portfolio P/L is now %@"),
                Self.formatPercent(percent)
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
