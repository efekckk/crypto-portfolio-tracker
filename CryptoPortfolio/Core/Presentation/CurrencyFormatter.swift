import Foundation

/// Locale-aware formatters for monetary and percent display. NumberFormatter is
/// expensive to construct; this type caches one per (locale identifier, currency code)
/// pair behind a serial queue.
enum CurrencyFormatter {

    // MARK: - Public API

    static func format(_ value: Double, currency: Currency, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(currency: currency, locale: locale)
        return formatter.string(from: NSNumber(value: value))
            ?? "\(currency.symbol)\(String(format: "%.2f", value))"
    }

    static func formatPercent(_ value: Double, locale: Locale = .current) -> String {
        let formatter = cachedDecimalFormatter(locale: locale)
        let abs = formatter.string(from: NSNumber(value: Swift.abs(value))) ?? "0.00"
        let sign = value < 0 ? "-" : "+"
        return "\(sign)\(abs)%"
    }

    // MARK: - Cache (exposed for tests)

    private static var currencyCache: [String: NumberFormatter] = [:]
    private static var decimalCache: [String: NumberFormatter] = [:]
    private static let queue = DispatchQueue(label: "CurrencyFormatter.cache")

    static func cachedFormatter(currency: Currency, locale: Locale) -> NumberFormatter {
        queue.sync {
            let key = "\(locale.identifier)-\(currency.code.uppercased())"
            if let cached = currencyCache[key] { return cached }
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            formatter.currencyCode = currency.code.uppercased()
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            currencyCache[key] = formatter
            return formatter
        }
    }

    static func cachedDecimalFormatter(locale: Locale) -> NumberFormatter {
        queue.sync {
            let key = locale.identifier
            if let cached = decimalCache[key] { return cached }
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            decimalCache[key] = formatter
            return formatter
        }
    }
}
