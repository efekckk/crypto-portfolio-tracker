import Foundation

/// A tradable coin with its latest market snapshot.
struct Coin: Identifiable, Equatable {
    let id: String          // CoinGecko id, e.g. "bitcoin"
    let symbol: String      // e.g. "btc"
    let name: String        // e.g. "Bitcoin"
    let imageURL: URL?
    let currentPrice: Double
    let priceChangePercentage24h: Double

    init(
        id: String,
        symbol: String,
        name: String,
        imageURL: URL? = nil,
        currentPrice: Double = 0,
        priceChangePercentage24h: Double = 0
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
    }
}
