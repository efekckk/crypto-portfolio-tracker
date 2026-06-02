import XCTest
@testable import CryptoPortfolio

final class CoinMapperTests: XCTestCase {
    func test_mapsMarketDTOToCoin() {
        let dto = CoinMarketDTO(
            id: "bitcoin", symbol: "btc", name: "Bitcoin",
            image: "https://example.com/btc.png",
            currentPrice: 50000, priceChangePercentage24h: 2.5
        )

        let coin = CoinMapper.map(dto)

        XCTAssertEqual(coin.id, "bitcoin")
        XCTAssertEqual(coin.symbol, "btc")
        XCTAssertEqual(coin.name, "Bitcoin")
        XCTAssertEqual(coin.imageURL, URL(string: "https://example.com/btc.png"))
        XCTAssertEqual(coin.currentPrice, 50000)
        XCTAssertEqual(coin.priceChangePercentage24h, 2.5)
    }

    func test_mapsMarketDTOWithNilsToZeroAndNilURL() {
        let dto = CoinMarketDTO(id: "x", symbol: "x", name: "X",
                                image: nil, currentPrice: nil, priceChangePercentage24h: nil)

        let coin = CoinMapper.map(dto)

        XCTAssertNil(coin.imageURL)
        XCTAssertEqual(coin.currentPrice, 0)
        XCTAssertEqual(coin.priceChangePercentage24h, 0)
    }

    func test_mapsSearchItemPreferringLargeImage_andZeroPrice() {
        let dto = CoinSearchItemDTO(id: "ethereum", name: "Ethereum", symbol: "ETH",
                                    thumb: "https://example.com/thumb.png",
                                    large: "https://example.com/large.png")

        let coin = CoinMapper.map(dto)

        XCTAssertEqual(coin.id, "ethereum")
        XCTAssertEqual(coin.imageURL, URL(string: "https://example.com/large.png"))
        XCTAssertEqual(coin.currentPrice, 0, "Search results carry no price")
    }

    func test_mapsMarketDTOStatsFields() {
        let dto = CoinMarketDTO(
            id: "bitcoin", symbol: "btc", name: "Bitcoin",
            image: nil, currentPrice: 50000, priceChangePercentage24h: 1.0,
            marketCap: 950_000_000_000, high24h: 51_000, low24h: 49_000
        )

        let coin = CoinMapper.map(dto)

        XCTAssertEqual(coin.marketCap, 950_000_000_000)
        XCTAssertEqual(coin.high24h, 51_000)
        XCTAssertEqual(coin.low24h, 49_000)
    }

    func test_marketMapping_wires7dAnd30dInto_Coin() {
        let dto = CoinMarketDTO(
            id: "btc", symbol: "btc", name: "Bitcoin",
            currentPrice: 75000,
            priceChangePercentage24h: 1.2,
            priceChangePercentage7dInCurrency: -3.4,
            priceChangePercentage30dInCurrency: 12.5
        )
        let coin = CoinMapper.map(dto)
        XCTAssertEqual(coin.priceChangePercentage7d, -3.4)
        XCTAssertEqual(coin.priceChangePercentage30d, 12.5)
    }
}
