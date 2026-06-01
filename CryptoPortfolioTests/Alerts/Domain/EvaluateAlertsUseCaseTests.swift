import XCTest
@testable import CryptoPortfolio

@MainActor
final class EvaluateAlertsUseCaseTests: XCTestCase {

    private let frozen = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSUT(alerts: [PriceAlert] = [], coins: [Coin] = [])
        -> (EvaluateAlertsUseCase, MockAlertRepository, MockCoinRepository) {
        let alertRepo = MockAlertRepository()
        for a in alerts { try? alertRepo.save(a) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        let sut = EvaluateAlertsUseCase(
            alertRepository: alertRepo, coinRepository: coinRepo, currency: .usd
        )
        return (sut, alertRepo, coinRepo)
    }

    func test_noActiveAlerts_returnsEmpty() async throws {
        let (sut, _, _) = makeSUT()
        let firings = try await sut(now: frozen)
        XCTAssertTrue(firings.isEmpty)
    }

    func test_inactiveAlertsAreSkipped() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above, isActive: false)
        let (sut, _, _) = makeSUT(alerts: [alert], coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)])

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty, "Inactive alerts must not fire")
    }

    func test_alreadyFiredAlertsAreSkipped() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above, isActive: true, firedAt: frozen)
        let (sut, _, _) = makeSUT(alerts: [alert], coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 60_000)])

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty, "Already-fired alerts must not fire again")
    }

    func test_aboveAlertFiresWhenPriceCrosses() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let (sut, repo, _) = makeSUT(
            alerts: [alert],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        )

        let firings = try await sut(now: frozen)

        XCTAssertEqual(firings.count, 1)
        XCTAssertEqual(firings.first?.firedAt, frozen)
        // Persisted with isActive false and firedAt set.
        let stored = try repo.alert(id: alert.id)
        XCTAssertEqual(stored?.isActive, false)
        XCTAssertEqual(stored?.firedAt, frozen)
    }

    func test_aboveAlertDoesNotFireWhenPriceBelowTarget() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 60_000, direction: .above)
        let (sut, _, _) = makeSUT(
            alerts: [alert],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        )

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty)
    }

    func test_belowAlertFiresWhenPriceAtOrBelow() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .below)
        let (sut, _, _) = makeSUT(
            alerts: [alert],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        )

        let firings = try await sut(now: frozen)

        XCTAssertEqual(firings.count, 1)
    }

    func test_missingPrice_skipsAlert() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let (sut, _, _) = makeSUT(alerts: [alert], coins: []) // markets returned nothing

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty)
    }

    func test_multipleAlertsAcrossCoins_fireIndependently() async throws {
        let btcAlert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let ethAlert = PriceAlert(coinId: "ethereum", targetPrice: 3_000, direction: .below)
        let (sut, _, _) = makeSUT(
            alerts: [btcAlert, ethAlert],
            coins: [
                Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000),
                Coin(id: "ethereum", symbol: "eth", name: "Ethereum", currentPrice: 4_000)
            ]
        )

        let firings = try await sut(now: frozen)

        XCTAssertEqual(firings.count, 1, "Only the BTC above-40k fires; ETH 4000 is not below 3000")
        XCTAssertEqual(firings.first?.alert.coinId, "bitcoin")
    }
}
