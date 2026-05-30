import XCTest
@testable import CryptoPortfolio

final class ChartPointMapperTests: XCTestCase {
    func test_mapsPricesArrayToChartPoints() {
        let dto = MarketChartDTO(prices: [
            [1_700_000_000_000, 50_000.5],
            [1_700_003_600_000, 50_250.0]
        ])

        let points = ChartPointMapper.map(dto)

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].id, 1_700_000_000_000)
        XCTAssertEqual(points[0].price, 50_000.5)
        XCTAssertEqual(points[0].date, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(points[1].id, 1_700_003_600_000)
    }

    func test_skipsMalformedPairs() {
        let dto = MarketChartDTO(prices: [
            [1_700_000_000_000, 50_000],
            [1_700_003_600_000]              // malformed (1-element)
        ])

        let points = ChartPointMapper.map(dto)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.id, 1_700_000_000_000)
    }
}
