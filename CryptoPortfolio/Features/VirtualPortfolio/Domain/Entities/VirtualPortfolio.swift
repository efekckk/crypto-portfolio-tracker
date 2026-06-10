import Foundation

/// Summary used by the list endpoint — compact computed snapshot per
/// portfolio so the list card can render without a per-portfolio detail call.
struct VirtualPortfolioSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let startingBalance: Double
    let cashBalance: Double
    let totalValue: Double
    let totalPnL: Double
    let totalPnLPercent: Double
    let tradeCount: Int
    let createdAt: Date
    let updatedAt: Date
}

/// Full detail of a single virtual portfolio: meta + computed state +
/// per-coin holdings with mark-to-market values.
struct VirtualPortfolio: Identifiable, Equatable {
    let id: UUID
    let name: String
    let startingBalance: Double
    let cashBalance: Double
    let totalValue: Double
    let realizedPnL: Double
    let unrealizedPnL: Double
    let totalPnLPercent: Double
    let holdings: [VirtualHolding]
    let createdAt: Date
    let updatedAt: Date
}

/// One coin position inside a virtual portfolio. The optional fields are nil
/// when the markets snapshot didn't contain the coin — UI shows "—".
struct VirtualHolding: Identifiable, Equatable {
    var id: String { coinId }
    let coinId: String
    let amount: Double
    let averageBuyPrice: Double
    let currentPrice: Double?
    let currentValue: Double?
    let unrealizedPnL: Double?
    let unrealizedPnLPercent: Double?
}
