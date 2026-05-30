import XCTest
@testable import CryptoPortfolio

final class CoinDTOTests: XCTestCase {
    func test_decodesCoinMarketDTOFromCoinGeckoJSON() throws {
        let json = """
        [{
          "id": "bitcoin",
          "symbol": "btc",
          "name": "Bitcoin",
          "image": "https://example.com/btc.png",
          "current_price": 50000.5,
          "price_change_percentage_24h": 2.34
        }]
        """.data(using: .utf8)!

        let dtos = try JSONDecoder().decode([CoinMarketDTO].self, from: json)

        XCTAssertEqual(dtos.count, 1)
        XCTAssertEqual(dtos[0].id, "bitcoin")
        XCTAssertEqual(dtos[0].symbol, "btc")
        XCTAssertEqual(dtos[0].name, "Bitcoin")
        XCTAssertEqual(dtos[0].image, "https://example.com/btc.png")
        XCTAssertEqual(dtos[0].currentPrice, 50000.5)
        XCTAssertEqual(dtos[0].priceChangePercentage24h, 2.34)
    }

    func test_decodesCoinMarketDTOWithMissingOptionalFields() throws {
        let json = """
        [{ "id": "x", "symbol": "x", "name": "X" }]
        """.data(using: .utf8)!

        let dtos = try JSONDecoder().decode([CoinMarketDTO].self, from: json)

        XCTAssertNil(dtos[0].image)
        XCTAssertNil(dtos[0].currentPrice)
        XCTAssertNil(dtos[0].priceChangePercentage24h)
    }

    func test_decodesSearchResponse() throws {
        let json = """
        {
          "coins": [
            { "id": "ethereum", "name": "Ethereum", "symbol": "ETH",
              "thumb": "https://example.com/eth-thumb.png",
              "large": "https://example.com/eth-large.png" }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CoinSearchResponseDTO.self, from: json)

        XCTAssertEqual(response.coins.count, 1)
        XCTAssertEqual(response.coins[0].id, "ethereum")
        XCTAssertEqual(response.coins[0].symbol, "ETH")
        XCTAssertEqual(response.coins[0].large, "https://example.com/eth-large.png")
    }

    func test_decodesCoinMarketDTOWithStatsFields() throws {
        let json = """
        [{
          "id": "bitcoin", "symbol": "btc", "name": "Bitcoin",
          "current_price": 50000,
          "price_change_percentage_24h": 1.0,
          "market_cap": 950000000000,
          "high_24h": 51000,
          "low_24h": 49000
        }]
        """.data(using: .utf8)!

        let dtos = try JSONDecoder().decode([CoinMarketDTO].self, from: json)

        XCTAssertEqual(dtos[0].marketCap, 950_000_000_000)
        XCTAssertEqual(dtos[0].high24h, 51_000)
        XCTAssertEqual(dtos[0].low24h, 49_000)
    }
}
