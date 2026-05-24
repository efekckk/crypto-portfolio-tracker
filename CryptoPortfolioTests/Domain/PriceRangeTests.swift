import XCTest
@testable import CryptoPortfolio

final class PriceRangeTests: XCTestCase {
    func test_coinGeckoDays_mapsEachCaseToExpectedValue() {
        XCTAssertEqual(PriceRange.h24.coinGeckoDays, "1")
        XCTAssertEqual(PriceRange.d7.coinGeckoDays, "7")
        XCTAssertEqual(PriceRange.d30.coinGeckoDays, "30")
        XCTAssertEqual(PriceRange.y1.coinGeckoDays, "365")
    }

    func test_allCases_areInChronologicalOrder() {
        XCTAssertEqual(PriceRange.allCases, [.h24, .d7, .d30, .y1])
    }
}
