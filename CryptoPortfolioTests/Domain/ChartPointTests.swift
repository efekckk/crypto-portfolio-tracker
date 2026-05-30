import XCTest
@testable import CryptoPortfolio

final class ChartPointTests: XCTestCase {
    func test_idIsAssignedExplicitly() {
        let point = ChartPoint(id: 1_700_000_000_000, date: Date(timeIntervalSince1970: 1_700_000_000), price: 50_000)
        XCTAssertEqual(point.id, 1_700_000_000_000)
        XCTAssertEqual(point.price, 50_000)
    }

    func test_twoPointsWithSameTimestampAreDistinctIfIDsDiffer() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = ChartPoint(id: 1, date: date, price: 10)
        let b = ChartPoint(id: 2, date: date, price: 20)
        XCTAssertNotEqual(a, b)
    }
}
