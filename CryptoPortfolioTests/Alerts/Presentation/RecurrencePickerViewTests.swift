import XCTest
@testable import CryptoPortfolio

final class RecurrencePickerStateTests: XCTestCase {
    func test_default_isOneShot() {
        XCTAssertEqual(RecurrencePickerState().recurrence, .oneShot)
    }

    func test_selectingCooldown_setsDefault1Hour() {
        var s = RecurrencePickerState()
        s.kind = .cooldown
        XCTAssertEqual(s.recurrence, .cooldown(seconds: 3600))
    }

    func test_pickingCooldown6h() {
        var s = RecurrencePickerState()
        s.kind = .cooldown
        s.cooldownSeconds = 21600
        XCTAssertEqual(s.recurrence, .cooldown(seconds: 21600))
    }

    func test_pickingOnCrossing() {
        var s = RecurrencePickerState()
        s.kind = .onCrossing
        XCTAssertEqual(s.recurrence, .onCrossing)
    }
}
