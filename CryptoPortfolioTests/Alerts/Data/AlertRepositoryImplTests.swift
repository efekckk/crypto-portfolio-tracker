import XCTest
@testable import CryptoPortfolio

final class AlertRepositoryImplTests: XCTestCase {
    private func makeSUT() -> AlertRepositoryImpl {
        AlertRepositoryImpl(stack: CoreDataStack(inMemory: true))
    }

    func test_alerts_startsEmpty() throws {
        XCTAssertTrue(try makeSUT().alerts().isEmpty)
    }

    func test_save_thenAlerts_returnsSaved() throws {
        let sut = makeSUT()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        try sut.save(alert)

        let stored = try sut.alerts()

        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.condition,
                       .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 50_000))
        XCTAssertTrue(stored.first?.isActive ?? false)
        XCTAssertNil(stored.first?.firedAt)
    }

    func test_save_withSameId_updatesInsteadOfDuplicating() throws {
        let sut = makeSUT()
        let id = UUID()
        try sut.save(PriceAlert(id: id, coinId: "bitcoin", targetPrice: 50_000, direction: .above))
        try sut.save(PriceAlert(id: id, coinId: "bitcoin", targetPrice: 60_000, direction: .above, isActive: false))

        let stored = try sut.alerts()

        XCTAssertEqual(stored.count, 1)
        if case .priceCrossing(_, _, let price) = stored.first?.condition {
            XCTAssertEqual(price, 60_000)
        } else {
            XCTFail("Expected priceCrossing condition")
        }
        XCTAssertFalse(stored.first?.isActive ?? true)
    }

    func test_alert_returnsNilWhenAbsent_andValueWhenPresent() throws {
        let sut = makeSUT()
        let id = UUID()
        XCTAssertNil(try sut.alert(id: id))

        try sut.save(PriceAlert(id: id, coinId: "bitcoin", targetPrice: 50_000, direction: .below))

        let alert = try sut.alert(id: id)
        XCTAssertEqual(alert?.condition,
                       .priceCrossing(coinId: "bitcoin", direction: .below, targetPrice: 50_000))
    }

    func test_delete_removesAlert() throws {
        let sut = makeSUT()
        let a = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let b = PriceAlert(coinId: "ethereum", targetPrice: 3_000, direction: .below)
        try sut.save(a)
        try sut.save(b)

        try sut.delete(id: a.id)

        let remaining = try sut.alerts()
        XCTAssertEqual(remaining.count, 1)
        if case .priceCrossing(let coinId, _, _) = remaining.first?.condition {
            XCTAssertEqual(coinId, "ethereum")
        } else {
            XCTFail("Expected priceCrossing condition")
        }
    }

    func test_firedAt_roundtripsCorrectly() throws {
        let sut = makeSUT()
        let firedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try sut.save(PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above, isActive: false, firedAt: firedAt))

        XCTAssertEqual(try sut.alerts().first?.firedAt, firedAt)
    }

    func test_save_priceCrossingOneShot_roundTrip() throws {
        let stack = CoreDataStack(inMemory: true)
        let repo = AlertRepositoryImpl(stack: stack)
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 75000, direction: .above)
        try repo.save(alert)
        let loaded = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertEqual(loaded.condition,
                       .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000))
        XCTAssertEqual(loaded.recurrence, .oneShot)
        XCTAssertNil(loaded.lastConditionResult)
    }

    func test_save_percentChange_cooldown_roundTrip() throws {
        let stack = CoreDataStack(inMemory: true)
        let repo = AlertRepositoryImpl(stack: stack)
        let alert = PriceAlert(
            condition: .percentChange(coinId: "ethereum", direction: .below, window: .d7, threshold: -5),
            recurrence: .cooldown(seconds: 3600)
        )
        try repo.save(alert)
        let loaded = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertEqual(loaded.condition,
                       .percentChange(coinId: "ethereum", direction: .below, window: .d7, threshold: -5))
        XCTAssertEqual(loaded.recurrence, .cooldown(seconds: 3600))
    }

    func test_save_portfolioValue_onCrossing_roundTrip_preservesLastResult() throws {
        let stack = CoreDataStack(inMemory: true)
        let repo = AlertRepositoryImpl(stack: stack)
        let alert = PriceAlert(
            condition: .portfolioValue(direction: .above, threshold: 100_000),
            recurrence: .onCrossing,
            lastConditionResult: true
        )
        try repo.save(alert)
        let loaded = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertEqual(loaded.condition, .portfolioValue(direction: .above, threshold: 100_000))
        XCTAssertEqual(loaded.recurrence, .onCrossing)
        XCTAssertEqual(loaded.lastConditionResult, true)
    }

    func test_legacyRow_withoutConditionJSON_decodesAsPriceCrossingOneShot() throws {
        // Simulate a v1.0 row by writing the legacy columns directly via Core Data
        // and leaving conditionJSON / recurrenceJSON nil.
        let stack = CoreDataStack(inMemory: true)
        let context = stack.viewContext
        let entity = CDAlert(context: context)
        let id = UUID()
        entity.id = id
        entity.coinId = "bitcoin"
        entity.targetPrice = 60000
        entity.direction = "below"
        entity.isActive = true
        entity.firedAt = nil
        entity.conditionJSON = nil
        entity.recurrenceJSON = nil
        entity.lastConditionResult = nil
        try context.save()

        let repo = AlertRepositoryImpl(stack: stack)
        let loaded = try XCTUnwrap(try repo.alert(id: id))
        XCTAssertEqual(loaded.condition,
                       .priceCrossing(coinId: "bitcoin", direction: .below, targetPrice: 60000))
        XCTAssertEqual(loaded.recurrence, .oneShot)
    }
}
