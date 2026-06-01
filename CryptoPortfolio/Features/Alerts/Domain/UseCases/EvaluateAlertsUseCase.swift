import Foundation

/// Pure-ish evaluation: read active alerts → fetch current prices → decide crossings →
/// persist `firedAt`/`isActive=false` → return firings for the caller to notify.
struct EvaluateAlertsUseCase {
    let alertRepository: AlertRepository
    let coinRepository: CoinRepository
    let currency: Currency

    func callAsFunction(now: Date = Date()) async throws -> [AlertFiring] {
        let active = try alertRepository.alerts().filter { $0.isActive && $0.firedAt == nil }
        guard !active.isEmpty else { return [] }
        let coinIds = Array(Set(active.map(\.coinId)))
        let coins = try await coinRepository.markets(ids: coinIds, currency: currency)
        let priceById = Dictionary(coins.map { ($0.id, $0.currentPrice) }, uniquingKeysWith: { first, _ in first })

        var firings: [AlertFiring] = []
        for alert in active {
            guard let price = priceById[alert.coinId] else { continue }
            let crossed: Bool
            switch alert.direction {
            case .above: crossed = price >= alert.targetPrice
            case .below: crossed = price <= alert.targetPrice
            }
            guard crossed else { continue }
            var fired = alert
            fired.isActive = false
            fired.firedAt = now
            try alertRepository.save(fired)
            firings.append(AlertFiring(alert: fired, firedAt: now))
        }
        return firings
    }
}
