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
        XCTAssertEqual(stored.first?.coinId, "bitcoin")
        XCTAssertEqual(stored.first?.targetPrice, 50_000)
        XCTAssertEqual(stored.first?.direction, .above)
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
        XCTAssertEqual(stored.first?.targetPrice, 60_000)
        XCTAssertFalse(stored.first?.isActive ?? true)
    }

    func test_alert_returnsNilWhenAbsent_andValueWhenPresent() throws {
        let sut = makeSUT()
        let id = UUID()
        XCTAssertNil(try sut.alert(id: id))

        try sut.save(PriceAlert(id: id, coinId: "bitcoin", targetPrice: 50_000, direction: .below))

        XCTAssertEqual(try sut.alert(id: id)?.targetPrice, 50_000)
    }

    func test_delete_removesAlert() throws {
        let sut = makeSUT()
        let a = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let b = PriceAlert(coinId: "ethereum", targetPrice: 3_000, direction: .below)
        try sut.save(a)
        try sut.save(b)

        try sut.delete(id: a.id)

        XCTAssertEqual(try sut.alerts().map(\.coinId), ["ethereum"])
    }

    func test_firedAt_roundtripsCorrectly() throws {
        let sut = makeSUT()
        let firedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try sut.save(PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above, isActive: false, firedAt: firedAt))

        XCTAssertEqual(try sut.alerts().first?.firedAt, firedAt)
    }
}
