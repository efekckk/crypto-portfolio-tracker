import Foundation

/// A user-defined firing rule. Polymorphic so we can express coin-price,
/// percent-change, and portfolio-level conditions in one column.
enum AlertCondition: Codable, Equatable {
    case priceCrossing(coinId: String, direction: Direction, targetPrice: Double)
    case percentChange(coinId: String, direction: Direction, window: PercentWindow, threshold: Double)
    case portfolioValue(direction: Direction, threshold: Double)
    case portfolioPnLPercent(direction: Direction, threshold: Double)

    enum Direction: String, Codable { case above, below }
    enum PercentWindow: String, Codable, CaseIterable { case h24, d7, d30 }

    /// Coin ids needed to evaluate this condition. `nil` means
    /// "all currently-held coins" (portfolio variants resolve their coin set
    /// from the user's holdings at evaluation time).
    var requiredCoinIds: Set<String>? {
        switch self {
        case .priceCrossing(let id, _, _), .percentChange(let id, _, _, _):
            return [id]
        case .portfolioValue, .portfolioPnLPercent:
            return nil
        }
    }
}
