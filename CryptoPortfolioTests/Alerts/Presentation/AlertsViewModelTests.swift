import XCTest
@testable import CryptoPortfolio

@MainActor
final class AlertsViewModelTests: XCTestCase {

    private func makeSUT(alerts: [PriceAlert] = [], coins: [Coin] = [], error: Error? = nil)
        -> (AlertsViewModel, MockAlertRepository, MockCoinRepository, SpyNotificationService) {
        let alertRepo = MockAlertRepository()
        for a in alerts { try? alertRepo.save(a) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        coinRepo.errorToThrow = error
        let notifications = SpyNotificationService()
        let vm = AlertsViewModel(
            getAlerts: GetAlertsUseCase(alertRepository: alertRepo),
            deleteAlert: DeleteAlertUseCase(alertRepository: alertRepo),
            setActive: SetAlertActiveUseCase(alertRepository: alertRepo),
            evaluate: EvaluateAlertsUseCase(alertRepository: alertRepo, coinRepository: coinRepo, portfolioRepository: MockPortfolioRepository(), currency: .usd),
            notifications: notifications
        )
        return (vm, alertRepo, coinRepo, notifications)
    }

    func test_initialState_isLoading() {
        let (sut, _, _, _) = makeSUT()
        XCTAssertEqual(sut.state, .loading)
    }

    func test_load_setsEmptyForNoAlerts() async {
        let (sut, _, _, _) = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_load_setsLoadedWithAlerts() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let (sut, _, _, _) = makeSUT(alerts: [alert])

        await sut.load()

        if case .loaded(let list) = sut.state {
            XCTAssertEqual(list.map(\.id), [alert.id])
        } else {
            XCTFail("Expected .loaded, got \(sut.state)")
        }
    }

    func test_delete_removesAlertAndReloads() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let (sut, repo, _, _) = makeSUT(alerts: [alert])
        await sut.load()

        await sut.delete(id: alert.id)

        XCTAssertTrue(try repo.alerts().isEmpty)
        XCTAssertEqual(sut.state, .empty)
    }

    func test_setActive_togglesAlertAndReloads() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above, isActive: true)
        let (sut, repo, _, _) = makeSUT(alerts: [alert])
        await sut.load()

        await sut.setActive(id: alert.id, isActive: false)

        XCTAssertEqual(try repo.alert(id: alert.id)?.isActive, false)
    }

    func test_evaluateNow_firesNotificationsForCrossedAlerts() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, _, _, notifications) = makeSUT(alerts: [alert], coins: [coin])
        await sut.load()

        await sut.evaluateNow()

        XCTAssertEqual(notifications.firings.count, 1)
        XCTAssertEqual(notifications.firings.first?.identifier, alert.id.uuidString)
    }

    func test_evaluateNow_doesNotFireWhenNoCrossings() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 60_000, direction: .above)
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, _, _, notifications) = makeSUT(alerts: [alert], coins: [coin])

        await sut.evaluateNow()

        XCTAssertTrue(notifications.firings.isEmpty)
    }
}
