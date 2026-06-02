import Foundation

/// Builds `Endpoint`s for the CoinGecko REST API.
enum CoinGeckoEndpoints {
    static func markets(ids: [String], vsCurrency: String) -> Endpoint {
        Endpoint(path: "coins/markets", queryItems: [
            URLQueryItem(name: "vs_currency", value: vsCurrency),
            URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
            URLQueryItem(name: "price_change_percentage", value: "24h,7d,30d")
        ])
    }

    static func search(query: String) -> Endpoint {
        Endpoint(path: "search", queryItems: [
            URLQueryItem(name: "query", value: query)
        ])
    }

    static func marketChart(coinId: String, vsCurrency: String, days: String) -> Endpoint {
        Endpoint(path: "coins/\(coinId)/market_chart", queryItems: [
            URLQueryItem(name: "vs_currency", value: vsCurrency),
            URLQueryItem(name: "days", value: days)
        ])
    }
}
