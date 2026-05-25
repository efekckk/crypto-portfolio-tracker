import Foundation

enum PortfolioError: Error, Equatable {
    case invalidAmount
}

struct AddHoldingUseCase {
    let portfolioRepository: PortfolioRepository

    /// Adds `amount` units bought at `buyPrice`. If a holding for `coinId` already
    /// exists, merges into it and recomputes the weighted average buy price.
    func callAsFunction(coinId: String, amount: Double, buyPrice: Double) throws {
        guard amount > 0 else { throw PortfolioError.invalidAmount }

        let merged: Holding
        if let existing = try portfolioRepository.holding(coinId: coinId) {
            let totalAmount = existing.amount + amount
            let weightedAverage = totalAmount > 0
                ? (existing.amount * existing.averageBuyPrice + amount * buyPrice) / totalAmount
                : buyPrice
            merged = Holding(coinId: coinId, amount: totalAmount,
                             averageBuyPrice: weightedAverage, dateAdded: existing.dateAdded)
        } else {
            merged = Holding(coinId: coinId, amount: amount, averageBuyPrice: buyPrice)
        }
        try portfolioRepository.save(merged)
    }
}
