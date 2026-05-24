import Foundation

/// Runtime configuration sourced from the Info.plist (populated by xcconfig).
enum AppConfig {
    static let coinGeckoBaseURL = URL(string: "https://api.coingecko.com/api/v3")!

    /// CoinGecko Demo API key, or nil when running keyless.
    static var coinGeckoAPIKey: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "COINGECKO_API_KEY") as? String
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
