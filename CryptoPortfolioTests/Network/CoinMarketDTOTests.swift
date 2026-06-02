import XCTest
@testable import CryptoPortfolio

final class CoinMarketDTOTests: XCTestCase {
    func test_decode_includes_7d_and_30d_percentChange() throws {
        let json = #"""
        {
          "id": "bitcoin", "symbol": "btc", "name": "Bitcoin",
          "current_price": 75000,
          "price_change_percentage_24h_in_currency": 1.2,
          "price_change_percentage_7d_in_currency": -3.4,
          "price_change_percentage_30d_in_currency": 12.5
        }
        """#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(CoinMarketDTO.self, from: json)
        XCTAssertEqual(dto.priceChangePercentage7dInCurrency, -3.4)
        XCTAssertEqual(dto.priceChangePercentage30dInCurrency, 12.5)
    }

    func test_decode_missingPercentFields_yieldsNil() throws {
        let json = #"{"id":"x","symbol":"x","name":"X"}"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(CoinMarketDTO.self, from: json)
        XCTAssertNil(dto.priceChangePercentage7dInCurrency)
        XCTAssertNil(dto.priceChangePercentage30dInCurrency)
    }
}
