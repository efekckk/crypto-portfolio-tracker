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
            priceChangePercentage24h: dto.priceChangePercentage24h ?? 0,
            marketCap: dto.marketCap,
            high24h: dto.high24h,
            low24h: dto.low24h,
            priceChangePercentage7d: dto.priceChangePercentage7dInCurrency,
            priceChangePercentage30d: dto.priceChangePercentage30dInCurrency
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
