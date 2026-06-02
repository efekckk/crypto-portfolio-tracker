import Foundation

/// One row from CoinGecko `/coins/markets`. Optional numeric fields tolerate
/// partial responses. Explicit CodingKeys because the shared decoder has no
/// key strategy configured.
struct CoinMarketDTO: Decodable {
    let id: String
    let symbol: String
    let name: String
    let image: String?
    let currentPrice: Double?
    let priceChangePercentage24h: Double?
    let marketCap: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChangePercentage7dInCurrency: Double?
    let priceChangePercentage30dInCurrency: Double?

    init(
        id: String,
        symbol: String,
        name: String,
        image: String? = nil,
        currentPrice: Double? = nil,
        priceChangePercentage24h: Double? = nil,
        marketCap: Double? = nil,
        high24h: Double? = nil,
        low24h: Double? = nil,
        priceChangePercentage7dInCurrency: Double? = nil,
        priceChangePercentage30dInCurrency: Double? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.image = image
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
        self.marketCap = marketCap
        self.high24h = high24h
        self.low24h = low24h
        self.priceChangePercentage7dInCurrency = priceChangePercentage7dInCurrency
        self.priceChangePercentage30dInCurrency = priceChangePercentage30dInCurrency
    }

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case marketCap = "market_cap"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChangePercentage7dInCurrency = "price_change_percentage_7d_in_currency"
        case priceChangePercentage30dInCurrency = "price_change_percentage_30d_in_currency"
    }
}
