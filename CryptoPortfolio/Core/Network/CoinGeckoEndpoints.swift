import Foundation

/// Builds `Endpoint`s for the CoinGecko REST API.
enum CoinGeckoEndpoints {
    static func markets(ids: [String], vsCurrency: String) -> Endpoint {
        Endpoint(path: "coins/markets", queryItems: [
            URLQueryItem(name: "vs_currency", value: vsCurrency),
            URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
            URLQueryItem(name: "price_change_percentage", value: "24h")
        ])
    }

    static func search(query: String) -> Endpoint {
        Endpoint(path: "search", queryItems: [
            URLQueryItem(name: "query", value: query)
        ])
    }
}
