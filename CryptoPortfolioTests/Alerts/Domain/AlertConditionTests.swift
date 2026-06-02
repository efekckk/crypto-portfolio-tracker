import XCTest
@testable import CryptoPortfolio

final class AlertConditionTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func test_priceCrossing_codable_roundTrip() throws {
        let original: AlertCondition = .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_percentChange_codable_roundTrip() throws {
        let original: AlertCondition = .percentChange(coinId: "ethereum", direction: .below, window: .d7, threshold: -5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_portfolioValue_codable_roundTrip() throws {
        let original: AlertCondition = .portfolioValue(direction: .above, threshold: 100_000)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_portfolioPnLPercent_codable_roundTrip() throws {
        let original: AlertCondition = .portfolioPnLPercent(direction: .below, threshold: -10)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_requiredCoinIds_priceCrossing_isSingleton() {
        let c: AlertCondition = .priceCrossing(coinId: "btc", direction: .above, targetPrice: 1)
        XCTAssertEqual(c.requiredCoinIds, ["btc"])
    }

    func test_requiredCoinIds_percentChange_isSingleton() {
        let c: AlertCondition = .percentChange(coinId: "eth", direction: .above, window: .h24, threshold: 1)
        XCTAssertEqual(c.requiredCoinIds, ["eth"])
    }

    func test_requiredCoinIds_portfolioVariants_areNil() {
        XCTAssertNil(AlertCondition.portfolioValue(direction: .above, threshold: 1).requiredCoinIds)
        XCTAssertNil(AlertCondition.portfolioPnLPercent(direction: .above, threshold: 1).requiredCoinIds)
    }
}
