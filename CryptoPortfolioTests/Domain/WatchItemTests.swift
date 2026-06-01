import XCTest
@testable import CryptoPortfolio

final class WatchItemTests: XCTestCase {
    func test_idIsCoinId() {
        let item = WatchItem(coinId: "bitcoin", addedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(item.id, "bitcoin")
        XCTAssertEqual(item.coinId, "bitcoin")
    }

    func test_initDefaultsAddedAtToNow() {
        let before = Date()
        let item = WatchItem(coinId: "bitcoin")
        let after = Date()
        XCTAssertTrue(item.addedAt >= before && item.addedAt <= after)
    }
}
