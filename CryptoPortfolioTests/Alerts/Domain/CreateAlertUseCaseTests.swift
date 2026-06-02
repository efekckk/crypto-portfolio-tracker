import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreateAlertUseCaseTests: XCTestCase {
    func test_newSignature_savesPercentChange_withCooldown() throws {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        try useCase(condition: .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5),
                    recurrence: .cooldown(seconds: 3600))
        let saved = try XCTUnwrap(try repo.alerts().first)
        XCTAssertEqual(saved.condition, .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5))
        XCTAssertEqual(saved.recurrence, .cooldown(seconds: 3600))
        XCTAssertTrue(saved.isActive)
        XCTAssertNil(saved.firedAt)
    }

    func test_priceCrossing_rejectsNonPositiveTarget() {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        XCTAssertThrowsError(try useCase(
            condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 0),
            recurrence: .oneShot
        )) { error in
            XCTAssertEqual(error as? AlertError, .invalidPrice)
        }
    }

    func test_portfolioValue_rejectsNonPositiveTarget() {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        XCTAssertThrowsError(try useCase(
            condition: .portfolioValue(direction: .above, threshold: -1),
            recurrence: .oneShot
        )) { error in
            XCTAssertEqual(error as? AlertError, .invalidPrice)
        }
    }

    func test_percentChange_rejectsZeroThreshold() {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        XCTAssertThrowsError(try useCase(
            condition: .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 0),
            recurrence: .oneShot
        )) { error in
            XCTAssertEqual(error as? AlertError, .invalidThreshold)
        }
    }

    func test_portfolioPnLPercent_rejectsZeroThreshold() {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        XCTAssertThrowsError(try useCase(
            condition: .portfolioPnLPercent(direction: .below, threshold: 0),
            recurrence: .oneShot
        )) { error in
            XCTAssertEqual(error as? AlertError, .invalidThreshold)
        }
    }

    func test_percentChange_acceptsNegativeThreshold() throws {
        // Spec: only zero is rejected. Negative thresholds are valid
        // (e.g., "alert if price drops 5%").
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        try useCase(
            condition: .percentChange(coinId: "btc", direction: .below, window: .d7, threshold: -5),
            recurrence: .oneShot
        )
        XCTAssertEqual(try repo.alerts().count, 1)
    }

    func test_portfolioPnLPercent_acceptsNegativeThreshold() throws {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        try useCase(
            condition: .portfolioPnLPercent(direction: .below, threshold: -10),
            recurrence: .oneShot
        )
        XCTAssertEqual(try repo.alerts().count, 1)
    }

    func test_legacyOverload_stillProducesPriceCrossingOneShot() throws {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        try useCase(coinId: "btc", targetPrice: 75000, direction: .above)
        let saved = try XCTUnwrap(try repo.alerts().first)
        XCTAssertEqual(saved.recurrence, .oneShot)
        XCTAssertEqual(saved.condition, .priceCrossing(coinId: "btc", direction: .above, targetPrice: 75000))
    }
}
