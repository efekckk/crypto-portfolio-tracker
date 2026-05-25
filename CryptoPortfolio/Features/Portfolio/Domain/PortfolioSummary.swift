import Foundation

/// A single holding valued at current price.
struct HoldingValuation: Identifiable, Equatable {
    var id: String { holding.coinId }
    let holding: Holding
    let coin: Coin?          // current market snapshot, if available
    let currentValue: Double // amount * current price
    let cost: Double         // amount * average buy price

    var absolutePnL: Double { currentValue - cost }
    var percentPnL: Double { cost > 0 ? (absolutePnL / cost) * 100 : 0 }
}

/// Aggregate valuation of the whole portfolio.
struct PortfolioSummary: Equatable {
    let totalValue: Double
    let totalCost: Double
    let absolutePnL: Double
    let percentPnL: Double
    let items: [HoldingValuation]

    static let empty = PortfolioSummary(
        totalValue: 0, totalCost: 0, absolutePnL: 0, percentPnL: 0, items: []
    )
}
