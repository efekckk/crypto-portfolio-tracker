import Foundation

/// Polymorphic alert evaluation. One consolidated markets fetch per pass.
/// Persists firing state (`firedAt`, `isActive`, `lastConditionResult`) and
/// returns one `AlertFiring` per alert that should notify the user this pass.
struct EvaluateAlertsUseCase {
    let alertRepository: AlertRepository
    let coinRepository: CoinRepository
    let portfolioRepository: PortfolioRepository
    let currency: Currency

    func callAsFunction(now: Date = Date()) async throws -> [AlertFiring] {
        let active = try alertRepository.alerts().filter { $0.isActive }
        guard !active.isEmpty else { return [] }

        // 1) Gather data requirements.
        var coinIds: Set<String> = []
        var needsPortfolio = false
        for alert in active {
            if let ids = alert.condition.requiredCoinIds {
                coinIds.formUnion(ids)
            } else {
                needsPortfolio = true
            }
        }
        var holdings: [Holding] = []
        if needsPortfolio {
            holdings = try portfolioRepository.holdings()
            coinIds.formUnion(holdings.map(\.coinId))
        }

        // 2) Single consolidated markets call.
        let coins: [Coin]
        if coinIds.isEmpty {
            coins = []
        } else {
            coins = try await coinRepository.markets(ids: Array(coinIds), currency: currency)
        }
        let coinsById = Dictionary(coins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // 3) Portfolio summary (only when needed). An empty-holdings portfolio
        //    is treated as "no data": evaluate() will return nil for portfolio
        //    variants, so a `.portfolioValue(.below, X)` alert doesn't spam a
        //    fresh user with "Portfolio total reached $0" notifications.
        let summary: PortfolioSummary? = (needsPortfolio && !holdings.isEmpty)
            ? Self.buildSummary(holdings: holdings, coinsById: coinsById)
            : nil

        // 4) Per-alert eval + fire-decision + persisted state update.
        //    We save per-alert rather than in a single transaction: a failure
        //    mid-loop leaves earlier alerts persisted and later ones unchanged,
        //    so on the next pass the unchanged ones simply re-evaluate from
        //    their pre-loop state — acceptable for best-effort notification.
        var firings: [AlertFiring] = []
        for alert in active {
            guard let result = evaluate(alert.condition,
                                        coinsById: coinsById,
                                        summary: summary) else {
                continue
            }
            let (conditionTrue, actualValue) = result
            var updated = alert
            if case .onCrossing = alert.recurrence {
                updated.lastConditionResult = conditionTrue
            }
            if shouldFire(alert, conditionTrue: conditionTrue, now: now) {
                updated.firedAt = now
                if case .oneShot = alert.recurrence { updated.isActive = false }
                let coinName = Self.coinName(for: alert.condition, coinsById: coinsById)
                firings.append(AlertFiring(alert: updated,
                                           firedAt: now,
                                           actualValue: actualValue,
                                           coinName: coinName))
            }
            if updated != alert {
                try alertRepository.save(updated)
            }
        }
        return firings
    }

    // MARK: - Per-variant evaluation

    /// Returns `(conditionTrue, actualValue)` or nil if required data is
    /// missing. `actualValue` is the measured number — current price, percent
    /// change, portfolio total, or P/L percent — that the threshold was
    /// compared against. Carrying it out lets notification copy reference
    /// what actually happened, not just the threshold that was crossed.
    private func evaluate(_ condition: AlertCondition,
                          coinsById: [String: Coin],
                          summary: PortfolioSummary?) -> (Bool, Double?)? {
        switch condition {
        case .priceCrossing(let coinId, let direction, let target):
            guard let coin = coinsById[coinId] else { return nil }
            let measured = coin.currentPrice
            switch direction {
            case .above: return (measured >= target, measured)
            case .below: return (measured <= target, measured)
            }
        case .percentChange(let coinId, let direction, let window, let threshold):
            guard let coin = coinsById[coinId] else { return nil }
            let value: Double?
            switch window {
            case .h24: value = coin.priceChangePercentage24h
            case .d7:  value = coin.priceChangePercentage7d
            case .d30: value = coin.priceChangePercentage30d
            }
            guard let measured = value else { return nil }
            switch direction {
            case .above: return (measured >= threshold, measured)
            case .below: return (measured <= threshold, measured)
            }
        case .portfolioValue(let direction, let threshold):
            guard let summary else { return nil }
            let measured = summary.totalValue
            switch direction {
            case .above: return (measured >= threshold, measured)
            case .below: return (measured <= threshold, measured)
            }
        case .portfolioPnLPercent(let direction, let threshold):
            guard let summary else { return nil }
            let measured = summary.percentPnL
            switch direction {
            case .above: return (measured >= threshold, measured)
            case .below: return (measured <= threshold, measured)
            }
        }
    }

    /// Looks up a presentable coin name for coin-bound condition variants.
    /// Returns nil for portfolio variants or when the coin id isn't in the
    /// markets response (graceful fallback handled downstream).
    private static func coinName(for condition: AlertCondition,
                                 coinsById: [String: Coin]) -> String? {
        switch condition {
        case .priceCrossing(let id, _, _), .percentChange(let id, _, _, _):
            return coinsById[id]?.name
        case .portfolioValue, .portfolioPnLPercent:
            return nil
        }
    }

    // MARK: - Recurrence state machine

    private func shouldFire(_ alert: PriceAlert,
                            conditionTrue: Bool,
                            now: Date) -> Bool {
        guard conditionTrue else { return false }
        switch alert.recurrence {
        case .oneShot:
            return alert.firedAt == nil
        case .cooldown(let seconds):
            guard let last = alert.firedAt else { return true }
            return now.timeIntervalSince(last) >= seconds
        case .onCrossing:
            return alert.lastConditionResult != true
        }
    }

    // MARK: - Summary

    /// Mirrors the math in `GetPortfolioSummaryUseCase` so portfolio-level
    /// conditions stay private to the evaluator (no cross-use-case dependency).
    /// **Keep these two in sync** — any change to portfolio P/L math must be
    /// applied in both places. Missing coins fall back to a current price of
    /// 0, matching `GetPortfolioSummaryUseCase` exactly (a partial-data
    /// summary is preferred over returning nothing).
    private static func buildSummary(holdings: [Holding],
                                     coinsById: [String: Coin]) -> PortfolioSummary {
        var items: [HoldingValuation] = []
        var totalValue = 0.0
        var totalCost = 0.0
        for holding in holdings {
            let coin = coinsById[holding.coinId]
            let price = coin?.currentPrice ?? 0
            let value = holding.amount * price
            let cost = holding.amount * holding.averageBuyPrice
            items.append(HoldingValuation(holding: holding, coin: coin,
                                          currentValue: value, cost: cost))
            totalValue += value
            totalCost += cost
        }
        let pnl = totalValue - totalCost
        let pct = totalCost > 0 ? (pnl / totalCost) * 100 : 0
        return PortfolioSummary(
            totalValue: totalValue, totalCost: totalCost,
            absolutePnL: pnl, percentPnL: pct, items: items
        )
    }
}
