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

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
    }
}
