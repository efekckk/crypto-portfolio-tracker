import XCTest
@testable import CryptoPortfolio

@MainActor
final class NotificationServiceTests: XCTestCase {

    func test_noOpService_returnsFalseAndDoesNothing() async {
        let sut: NotificationService = NoOpNotificationService()
        let granted = await sut.requestAuthorizationIfNeeded()
        await sut.fire(title: "x", body: "y", identifier: "id")
        XCTAssertFalse(granted)
    }

    func test_spyRecordsFiringsAndAuthorizationCalls() async {
        let sut = SpyNotificationService()
        _ = await sut.requestAuthorizationIfNeeded()
        await sut.fire(title: "Hi", body: "Body", identifier: "id-1")
        XCTAssertEqual(sut.authorizationCalls, 1)
        XCTAssertEqual(sut.firings.count, 1)
        XCTAssertEqual(sut.firings.first?.identifier, "id-1")
    }

    func test_evaluateAndNotify_firesForCrossedAlerts() async throws {
        let stack = CoreDataStack(inMemory: true)
        let notifications = SpyNotificationService()
        let container = AppContainer(coreDataStack: stack, notifications: notifications)
        // Seed: one above alert at 40k for bitcoin.
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        try container.alertRepository.save(alert)
        // Swap the coinRepository with a stub returning a current price of 50k.
        container.coinRepository = StubCoinRepository(price: 50_000)

        let count = await container.evaluateAndNotify(currency: .usd)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(notifications.firings.count, 1)
        XCTAssertEqual(notifications.firings.first?.identifier, alert.id.uuidString)
    }
}

/// Minimal stub used only for this test — returns a single coin with the requested price.
private final class StubCoinRepository: CoinRepository {
    private let price: Double
    init(price: Double) { self.price = price }

    func searchCoins(query: String) async throws -> [Coin] { [] }
    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        ids.map { Coin(id: $0, symbol: $0, name: $0, currentPrice: price) }
    }
    func chart(coinId: String, range: PriceRange, currency: Currency) async throws -> [ChartPoint] { [] }
}
