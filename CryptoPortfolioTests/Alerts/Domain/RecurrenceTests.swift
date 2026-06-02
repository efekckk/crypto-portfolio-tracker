import XCTest
@testable import CryptoPortfolio

final class RecurrenceTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func test_oneShot_roundTrip() throws {
        let data = try encoder.encode(Recurrence.oneShot)
        XCTAssertEqual(try decoder.decode(Recurrence.self, from: data), .oneShot)
    }

    func test_cooldown_roundTrip_preservesInterval() throws {
        let data = try encoder.encode(Recurrence.cooldown(seconds: 3600))
        XCTAssertEqual(try decoder.decode(Recurrence.self, from: data), .cooldown(seconds: 3600))
    }

    func test_onCrossing_roundTrip() throws {
        let data = try encoder.encode(Recurrence.onCrossing)
        XCTAssertEqual(try decoder.decode(Recurrence.self, from: data), .onCrossing)
    }
}
