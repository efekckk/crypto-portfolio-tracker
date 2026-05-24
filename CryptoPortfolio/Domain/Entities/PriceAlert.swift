import Foundation

/// A user-defined price threshold for a coin.
struct PriceAlert: Identifiable, Equatable {
    enum Direction: String {
        case above
        case below
    }

    let id: UUID
    let coinId: String
    let targetPrice: Double
    let direction: Direction
    var isActive: Bool
    var firedAt: Date?

    init(
        id: UUID = UUID(),
        coinId: String,
        targetPrice: Double,
        direction: Direction,
        isActive: Bool = true,
        firedAt: Date? = nil
    ) {
        self.id = id
        self.coinId = coinId
        self.targetPrice = targetPrice
        self.direction = direction
        self.isActive = isActive
        self.firedAt = firedAt
    }
}
