import Foundation

// MARK: - List

struct VirtualPortfoliosListResponseDTO: Decodable {
    let portfolios: [VirtualPortfolioSummaryDTO]
}

struct VirtualPortfolioSummaryDTO: Decodable {
    let id: String
    let name: String
    let startingBalance: Double
    let cashBalance: Double
    let totalValue: Double
    let totalPnl: Double
    let totalPnlPercent: Double
    let tradeCount: Int
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> VirtualPortfolioSummary? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return VirtualPortfolioSummary(
            id: uuid, name: name, startingBalance: startingBalance,
            cashBalance: cashBalance, totalValue: totalValue,
            totalPnL: totalPnl, totalPnLPercent: totalPnlPercent,
            tradeCount: tradeCount, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

// MARK: - Detail

struct VirtualHoldingDTO: Decodable {
    let coinId: String
    let amount: Double
    let averageBuyPrice: Double
    let currentPrice: Double?
    let currentValue: Double?
    let unrealizedPnl: Double?
    let unrealizedPnlPercent: Double?

    func toDomain() -> VirtualHolding {
        VirtualHolding(
            coinId: coinId, amount: amount, averageBuyPrice: averageBuyPrice,
            currentPrice: currentPrice, currentValue: currentValue,
            unrealizedPnL: unrealizedPnl, unrealizedPnLPercent: unrealizedPnlPercent
        )
    }
}

struct VirtualPortfolioDetailDTO: Decodable {
    let id: String
    let name: String
    let startingBalance: Double
    let cashBalance: Double
    let totalValue: Double
    let realizedPnl: Double
    let unrealizedPnl: Double
    let totalPnlPercent: Double
    let holdings: [VirtualHoldingDTO]
    let createdAt: Date
    let updatedAt: Date

    func toDomain() -> VirtualPortfolio? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return VirtualPortfolio(
            id: uuid, name: name, startingBalance: startingBalance,
            cashBalance: cashBalance, totalValue: totalValue,
            realizedPnL: realizedPnl, unrealizedPnL: unrealizedPnl,
            totalPnLPercent: totalPnlPercent,
            holdings: holdings.map { $0.toDomain() },
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

struct VirtualPortfolioCreateResponseDTO: Decodable {
    let id: String
    let name: String
    let startingBalance: Double
    let createdAt: Date
}

// MARK: - Quote

struct VirtualQuoteDTO: Decodable {
    let coinId: String
    let coinName: String
    let price: Double
    let fetchedAt: Date
    let maxBuyAmount: Double
    let maxSellAmount: Double

    func toDomain() -> VirtualQuote {
        VirtualQuote(
            coinId: coinId, coinName: coinName, price: price,
            fetchedAt: fetchedAt,
            maxBuyAmount: maxBuyAmount, maxSellAmount: maxSellAmount
        )
    }
}

// MARK: - Trades

struct VirtualTradeDTO: Decodable {
    let id: Int64
    let side: String
    let coinId: String
    let amount: Double
    let price: Double
    let executedAt: Date

    func toDomain() -> VirtualTrade? {
        guard let s = VirtualTrade.Side(rawValue: side) else { return nil }
        return VirtualTrade(
            id: id, side: s, coinId: coinId,
            amount: amount, price: price, executedAt: executedAt
        )
    }
}

struct VirtualTradeHistoryPageDTO: Decodable {
    let trades: [VirtualTradeDTO]
    let nextCursor: Int64?

    func toDomain() -> VirtualTradeHistoryPage {
        VirtualTradeHistoryPage(
            trades: trades.compactMap { $0.toDomain() },
            nextCursor: nextCursor
        )
    }
}

struct ExecuteTradeResponseDTO: Decodable {
    let trade: VirtualTradeDTO
    let portfolio: VirtualPortfolioDetailDTO
}
