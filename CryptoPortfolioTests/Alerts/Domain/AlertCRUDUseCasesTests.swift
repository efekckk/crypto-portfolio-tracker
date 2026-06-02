import XCTest
@testable import CryptoPortfolio

@MainActor
final class AlertCRUDUseCasesTests: XCTestCase {
    func test_getAlerts_delegatesToRepository() throws {
        let repo = MockAlertRepository()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        try repo.save(alert)
        let sut = GetAlertsUseCase(alertRepository: repo)

        XCTAssertEqual(try sut().count, 1)
    }

    func test_createAlert_savesNewAlert() throws {
        let repo = MockAlertRepository()
        let sut = CreateAlertUseCase(alertRepository: repo)

        try sut(coinId: "bitcoin", targetPrice: 50_000, direction: .above)

        XCTAssertEqual(try repo.alerts().count, 1)
        let alert = try repo.alerts().first
        XCTAssertEqual(alert?.condition,
                       .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 50_000))
    }

    func test_createAlert_throwsOnNonPositivePrice() {
        let repo = MockAlertRepository()
        let sut = CreateAlertUseCase(alertRepository: repo)

        XCTAssertThrowsError(try sut(coinId: "bitcoin", targetPrice: 0, direction: .above)) { error in
            XCTAssertEqual(error as? AlertError, .invalidPrice)
        }
    }

    func test_deleteAlert_removesAlert() throws {
        let repo = MockAlertRepository()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        try repo.save(alert)
        let sut = DeleteAlertUseCase(alertRepository: repo)

        try sut(id: alert.id)

        XCTAssertTrue(try repo.alerts().isEmpty)
    }

    func test_setAlertActive_togglesIsActive() throws {
        let repo = MockAlertRepository()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above, isActive: true)
        try repo.save(alert)
        let sut = SetAlertActiveUseCase(alertRepository: repo)

        try sut(id: alert.id, isActive: false)

        XCTAssertEqual(try repo.alert(id: alert.id)?.isActive, false)
    }

    func test_setAlertActive_isNoOpForUnknownId() throws {
        let repo = MockAlertRepository()
        let sut = SetAlertActiveUseCase(alertRepository: repo)

        // Should not throw, should not mutate.
        try sut(id: UUID(), isActive: true)

        XCTAssertTrue(try repo.alerts().isEmpty)
    }

    func test_setAlertActive_true_clearsFiredAt() throws {
        let repo = MockAlertRepository()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above,
                               isActive: false, firedAt: Date(timeIntervalSince1970: 1))
        try repo.save(alert)
        let sut = SetAlertActiveUseCase(alertRepository: repo)

        try sut(id: alert.id, isActive: true)

        let updated = try repo.alert(id: alert.id)
        XCTAssertEqual(updated?.isActive, true)
        XCTAssertNil(updated?.firedAt, "Re-arming must clear firedAt so the alert can fire again")
    }
}
