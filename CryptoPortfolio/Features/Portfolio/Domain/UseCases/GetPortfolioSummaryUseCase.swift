import Foundation

/// Combines persisted holdings with current market prices to compute portfolio
/// value and profit/loss. All money math lives here.
struct GetPortfolioSummaryUseCase {
    let portfolioRepository: PortfolioRepository
    let coinRepository: CoinRepository

    func callAsFunction(currency: Currency) async throws -> PortfolioSummary {
        let holdings = try portfolioRepository.holdings()
        guard !holdings.isEmpty else { return .empty }

        let coins = try await coinRepository.markets(ids: holdings.map(\.coinId), currency: currency)
        let coinsById = Dictionary(coins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var items: [HoldingValuation] = []
        var totalValue = 0.0
        var totalCost = 0.0

        for holding in holdings {
            let coin = coinsById[holding.coinId]
            let price = coin?.currentPrice ?? 0
            let value = holding.amount * price
            let cost = holding.amount * holding.averageBuyPrice
            items.append(HoldingValuation(holding: holding, coin: coin, currentValue: value, cost: cost))
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
