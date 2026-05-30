import XCTest
@testable import CryptoPortfolio

final class MarketChartDTOTests: XCTestCase {
    func test_decodesPricesArray() throws {
        let json = """
        {
          "prices": [[1700000000000, 50000.5], [1700003600000, 50250.0]]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MarketChartDTO.self, from: json)

        XCTAssertEqual(dto.prices.count, 2)
        XCTAssertEqual(dto.prices[0], [1700000000000, 50000.5])
        XCTAssertEqual(dto.prices[1][1], 50250.0)
    }

    func test_decodesIgnoresOtherTopLevelKeys() throws {
        let json = """
        {
          "prices": [[1, 2]],
          "market_caps": [[1, 100]],
          "total_volumes": [[1, 200]]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(MarketChartDTO.self, from: json)

        XCTAssertEqual(dto.prices.count, 1)
    }
}
