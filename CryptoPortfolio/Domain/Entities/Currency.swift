import Foundation

/// Quote/display currency. `code` is the CoinGecko `vs_currency` parameter.
enum Currency: String, CaseIterable, Identifiable {
    case usd
    case tryLira = "try"   // `try` is a Swift keyword; raw value is the API code

    static let `default`: Currency = .usd

    var id: String { rawValue }
    var code: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .tryLira: return "₺"
        }
    }
}
