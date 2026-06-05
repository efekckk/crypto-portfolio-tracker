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
            alertRepository: alertRepo,
            coinRepository: coinRepo,
            portfolioRepository: MockPortfolioRepository(),
            currency: .usd
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
        if case .priceCrossing(let coinId, _, _) = firings.first?.alert.condition {
            XCTAssertEqual(coinId, "bitcoin")
        } else {
            XCTFail("Expected priceCrossing condition")
        }
    }

    func test_aboveAlertFiresAtExactTarget() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let (sut, _, _) = makeSUT(
            alerts: [alert],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        )

        let firings = try await sut(now: frozen)

        XCTAssertEqual(firings.count, 1, "Above-50k alert must fire when price == 50k (inclusive)")
    }

    // MARK: - Helpers used by tests below

    private func evaluator(
        alerts: [PriceAlert] = [],
        holdings: [Holding] = [],
        coins: [Coin] = []
    ) -> (EvaluateAlertsUseCase, MockAlertRepository, MockPortfolioRepository, MockCoinRepository) {
        let alertRepo = MockAlertRepository()
        for a in alerts { try? alertRepo.save(a) }
        let portfolioRepo = MockPortfolioRepository()
        for h in holdings { try? portfolioRepo.save(h) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        let useCase = EvaluateAlertsUseCase(
            alertRepository: alertRepo,
            coinRepository: coinRepo,
            portfolioRepository: portfolioRepo,
            currency: .usd
        )
        return (useCase, alertRepo, portfolioRepo, coinRepo)
    }

    private func coin(_ id: String,
                      price: Double = 0,
                      p24h: Double = 0,
                      p7d: Double? = nil,
                      p30d: Double? = nil) -> Coin {
        Coin(id: id, symbol: id, name: id.capitalized,
             currentPrice: price, priceChangePercentage24h: p24h,
             priceChangePercentage7d: p7d, priceChangePercentage30d: p30d)
    }

    // MARK: - .priceCrossing

    func test_priceCrossing_above_fires_whenPriceMeetsTarget_oneShot() async throws {
        let alert = PriceAlert(coinId: "btc", targetPrice: 75000, direction: .above)
        let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 75000)])
        let firings = try await useCase()
        XCTAssertEqual(firings.count, 1)
        let saved = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertFalse(saved.isActive)
        XCTAssertNotNil(saved.firedAt)
    }

    func test_priceCrossing_above_doesNotFire_whenPriceBelowTarget() async throws {
        let alert = PriceAlert(coinId: "btc", targetPrice: 75000, direction: .above)
        let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 74999)])
        let firings = try await useCase()
        XCTAssertTrue(firings.isEmpty)
    }

    // MARK: - .percentChange

    func test_percentChange_above_24h_fires_whenChangeMeetsThreshold() async throws {
        let alert = PriceAlert(
            condition: .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5),
            recurrence: .oneShot
        )
        let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", p24h: 6)])
        let firings = try await useCase()
        XCTAssertEqual(firings.count, 1)
    }

    func test_percentChange_below_7d_fires_whenChangeMeetsThreshold() async throws {
        let alert = PriceAlert(
            condition: .percentChange(coinId: "btc", direction: .below, window: .d7, threshold: -10),
            recurrence: .oneShot
        )
        let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", p7d: -12)])
        let firings = try await useCase()
        XCTAssertEqual(firings.count, 1)
    }

    func test_percentChange_30d_missingField_skipsWithoutStateChange() async throws {
        let alert = PriceAlert(
            condition: .percentChange(coinId: "btc", direction: .above, window: .d30, threshold: 5),
            recurrence: .oneShot
        )
        let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", p30d: nil)])
        let firings = try await useCase()
        XCTAssertTrue(firings.isEmpty)
        let saved = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertTrue(saved.isActive)
        XCTAssertNil(saved.firedAt)
    }

    // MARK: - .portfolioValue

    func test_portfolioValue_above_fires_whenTotalValueMeetsThreshold() async throws {
        let alert = PriceAlert(
            condition: .portfolioValue(direction: .above, threshold: 100_000),
            recurrence: .oneShot
        )
        let holding = Holding(coinId: "btc", amount: 2, averageBuyPrice: 30000)
        let (useCase, _, _, _) = evaluator(alerts: [alert],
                                            holdings: [holding],
                                            coins: [coin("btc", price: 60000)])
        let firings = try await useCase()
        XCTAssertEqual(firings.count, 1)
    }

    // MARK: - .portfolioPnLPercent

    func test_portfolioPnLPercent_below_fires_whenPnLPercentBeatsThreshold() async throws {
        let alert = PriceAlert(
            condition: .portfolioPnLPercent(direction: .below, threshold: -10),
            recurrence: .oneShot
        )
        let holding = Holding(coinId: "btc", amount: 1, averageBuyPrice: 100)
        let (useCase, _, _, _) = evaluator(alerts: [alert],
                                            holdings: [holding],
                                            coins: [coin("btc", price: 80)])
        let firings = try await useCase()
        XCTAssertEqual(firings.count, 1)
    }

    func test_portfolioValue_emptyHoldings_doesNotFire() async throws {
        // A fresh user with no holdings shouldn't get "Portfolio total
        // reached $0" for a `.below`-direction alert.
        let alert = PriceAlert(
            condition: .portfolioValue(direction: .below, threshold: 100),
            recurrence: .oneShot
        )
        let (useCase, repo, _, _) = evaluator(alerts: [alert], holdings: [], coins: [])
        let firings = try await useCase()
        XCTAssertTrue(firings.isEmpty)
        let saved = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertTrue(saved.isActive)
        XCTAssertNil(saved.firedAt)
    }

    // MARK: - Recurrence: cooldown

    func test_cooldown_doesNotFire_beforeIntervalElapses() async throws {
        let now = Date(timeIntervalSince1970: 1000)
        let alert = PriceAlert(
            condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
            recurrence: .cooldown(seconds: 3600),
            firedAt: Date(timeIntervalSince1970: 500)
        )
        let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
        let firings = try await useCase(now: now)
        XCTAssertTrue(firings.isEmpty)
    }

    func test_cooldown_fires_afterIntervalElapses() async throws {
        let now = Date(timeIntervalSince1970: 5000)
        let alert = PriceAlert(
            condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
            recurrence: .cooldown(seconds: 3600),
            firedAt: Date(timeIntervalSince1970: 500)
        )
        let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
        let firings = try await useCase(now: now)
        XCTAssertEqual(firings.count, 1)
        let saved = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertTrue(saved.isActive)
        XCTAssertEqual(saved.firedAt, now)
    }

    // MARK: - Recurrence: onCrossing

    func test_onCrossing_fires_onFalseToTrueTransition() async throws {
        let alert = PriceAlert(
            condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
            recurrence: .onCrossing,
            lastConditionResult: false
        )
        let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
        let firings = try await useCase()
        XCTAssertEqual(firings.count, 1)
        let saved = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertEqual(saved.lastConditionResult, true)
        XCTAssertTrue(saved.isActive)
    }

    func test_onCrossing_doesNotFire_whenAlreadyTrue() async throws {
        let alert = PriceAlert(
            condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
            recurrence: .onCrossing,
            lastConditionResult: true
        )
        let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
        let firings = try await useCase()
        XCTAssertTrue(firings.isEmpty)
    }

    func test_onCrossing_firesAgain_afterTransientFalse() async throws {
        let alert = PriceAlert(
            condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
            recurrence: .onCrossing,
            lastConditionResult: true
        )
        let (useCase1, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 90)])
        _ = try await useCase1()
        let afterDip = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertEqual(afterDip.lastConditionResult, false)
        XCTAssertTrue(afterDip.isActive)

        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = [coin("btc", price: 120)]
        let useCase2 = EvaluateAlertsUseCase(
            alertRepository: repo,
            coinRepository: coinRepo,
            portfolioRepository: MockPortfolioRepository(),
            currency: .usd
        )
        let firings = try await useCase2()
        XCTAssertEqual(firings.count, 1)
        let afterRecovery = try XCTUnwrap(try repo.alert(id: alert.id))
        XCTAssertEqual(afterRecovery.lastConditionResult, true)
    }

    // MARK: - Consolidation

    func test_singleMarketsCall_perPass_regardlessOfConditionMix() async throws {
        let a1 = PriceAlert(coinId: "btc", targetPrice: 1, direction: .above)
        let a2 = PriceAlert(
            condition: .percentChange(coinId: "eth", direction: .above, window: .h24, threshold: 1),
            recurrence: .oneShot
        )
        let a3 = PriceAlert(
            condition: .portfolioValue(direction: .above, threshold: 1),
            recurrence: .oneShot
        )
        let holding = Holding(coinId: "doge", amount: 1, averageBuyPrice: 0.1)
        let (useCase, _, _, coinRepo) = evaluator(
            alerts: [a1, a2, a3],
            holdings: [holding],
            coins: [coin("btc", price: 2), coin("eth", p24h: 2), coin("doge", price: 0.2)]
        )
        _ = try await useCase()
        XCTAssertEqual(coinRepo.marketsCallCount, 1)
    }

    // MARK: - Firing detail: actualValue + coinName

    func test_priceCrossing_firing_carriesCurrentPrice_andCoinName() async throws {
        let alert = PriceAlert(coinId: "btc", targetPrice: 75000, direction: .above)
        let (useCase, _, _, _) = evaluator(
            alerts: [alert],
            coins: [Coin(id: "btc", symbol: "btc", name: "Bitcoin",
                         currentPrice: 80000, priceChangePercentage24h: 0)]
        )
        let firings = try await useCase()
        let firing = try XCTUnwrap(firings.first)
        XCTAssertEqual(firing.actualValue, 80000)
        XCTAssertEqual(firing.coinName, "Bitcoin")
    }

    func test_percentChange_firing_carriesMeasuredPercent_andCoinName() async throws {
        let alert = PriceAlert(
            condition: .percentChange(coinId: "eth", direction: .above, window: .h24, threshold: 5),
            recurrence: .oneShot
        )
        let (useCase, _, _, _) = evaluator(
            alerts: [alert],
            coins: [Coin(id: "eth", symbol: "eth", name: "Ethereum",
                         currentPrice: 0, priceChangePercentage24h: 8.2)]
        )
        let firings = try await useCase()
        let firing = try XCTUnwrap(firings.first)
        XCTAssertEqual(firing.actualValue, 8.2)
        XCTAssertEqual(firing.coinName, "Ethereum")
    }

    func test_portfolioValue_firing_carriesTotalValue_andNoCoinName() async throws {
        let alert = PriceAlert(
            condition: .portfolioValue(direction: .above, threshold: 100_000),
            recurrence: .oneShot
        )
        let holding = Holding(coinId: "btc", amount: 2, averageBuyPrice: 30000)
        let (useCase, _, _, _) = evaluator(
            alerts: [alert],
            holdings: [holding],
            coins: [coin("btc", price: 60000)]
        )
        let firings = try await useCase()
        let firing = try XCTUnwrap(firings.first)
        XCTAssertEqual(firing.actualValue, 120_000)
        XCTAssertNil(firing.coinName)
    }

    func test_portfolioPnLPercent_firing_carriesMeasuredPnL_andNoCoinName() async throws {
        let alert = PriceAlert(
            condition: .portfolioPnLPercent(direction: .below, threshold: -10),
            recurrence: .oneShot
        )
        let holding = Holding(coinId: "btc", amount: 1, averageBuyPrice: 100)
        let (useCase, _, _, _) = evaluator(
            alerts: [alert],
            holdings: [holding],
            coins: [coin("btc", price: 80)]
        )
        let firings = try await useCase()
        let firing = try XCTUnwrap(firings.first)
        // Bought 1 @100, now worth 80 → P/L = -20%
        XCTAssertEqual(firing.actualValue ?? 0, -20, accuracy: 0.0001)
        XCTAssertNil(firing.coinName)
    }
}
