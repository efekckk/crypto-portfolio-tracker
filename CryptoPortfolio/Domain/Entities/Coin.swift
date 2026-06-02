import Foundation

/// A tradable coin with its latest market snapshot. Stats fields are optional
/// because not every code path needs them (search results carry no price/stats).
struct Coin: Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let imageURL: URL?
    let currentPrice: Double
    let priceChangePercentage24h: Double
    let marketCap: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChangePercentage7d: Double?
    let priceChangePercentage30d: Double?

    init(
        id: String,
        symbol: String,
        name: String,
        imageURL: URL? = nil,
        currentPrice: Double = 0,
        priceChangePercentage24h: Double = 0,
        marketCap: Double? = nil,
        high24h: Double? = nil,
        low24h: Double? = nil,
        priceChangePercentage7d: Double? = nil,
        priceChangePercentage30d: Double? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
        self.marketCap = marketCap
        self.high24h = high24h
        self.low24h = low24h
        self.priceChangePercentage7d = priceChangePercentage7d
        self.priceChangePercentage30d = priceChangePercentage30d
    }
}
