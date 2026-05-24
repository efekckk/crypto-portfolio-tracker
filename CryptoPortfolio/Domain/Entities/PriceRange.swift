import Foundation

/// Chart time ranges offered in CoinDetail, with the CoinGecko `days` parameter.
enum PriceRange: String, CaseIterable, Identifiable {
    case h24
    case d7
    case d30
    case y1

    var id: String { rawValue }

    /// Value for CoinGecko `/coins/{id}/market_chart?days=`.
    var coinGeckoDays: String {
        switch self {
        case .h24: return "1"
        case .d7: return "7"
        case .d30: return "30"
        case .y1: return "365"
        }
    }

    /// Short label for the segmented selector.
    var displayLabel: String {
        switch self {
        case .h24: return "24s"
        case .d7: return "7g"
        case .d30: return "30g"
        case .y1: return "1y"
        }
    }
}
