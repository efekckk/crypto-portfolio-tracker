import Foundation

/// Locale-aware formatters for monetary and percent display.
enum CurrencyFormatter {
    /// Formats a monetary `Double` using ISO 4217 code from `Currency`.
    static func format(_ value: Double, currency: Currency, locale: Locale = .current) -> String {
        let code = currency.code.uppercased()
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? "\(currency.symbol)\(String(format: "%.2f", value))"
    }

    /// Formats a signed percent like `+2.50%` / `-1.00%` (always two fraction digits, always a sign).
    static func formatPercent(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let abs = formatter.string(from: NSNumber(value: Swift.abs(value))) ?? "0.00"
        let sign = value < 0 ? "-" : "+"
        return "\(sign)\(abs)%"
    }
}
