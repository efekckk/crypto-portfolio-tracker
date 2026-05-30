import Foundation

/// Maps CoinGecko DTOs to the domain `Coin` entity.
enum CoinMapper {
    static func map(_ dto: CoinMarketDTO) -> Coin {
        Coin(
            id: dto.id,
            symbol: dto.symbol,
            name: dto.name,
            imageURL: dto.image.flatMap(URL.init(string:)),
            currentPrice: dto.currentPrice ?? 0,
            priceChangePercentage24h: dto.priceChangePercentage24h ?? 0
        )
    }

    static func map(_ dto: CoinSearchItemDTO) -> Coin {
        Coin(
            id: dto.id,
            symbol: dto.symbol,
            name: dto.name,
            imageURL: (dto.large ?? dto.thumb).flatMap(URL.init(string:)),
            currentPrice: 0,
            priceChangePercentage24h: 0
        )
    }
}
