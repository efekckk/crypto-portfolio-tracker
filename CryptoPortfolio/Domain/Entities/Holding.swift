import Foundation

/// A user's position in a single coin. One Holding per coin id.
struct Holding: Identifiable, Equatable {
    var id: String { coinId }
    let coinId: String
    let amount: Double          // units held
    let averageBuyPrice: Double // weighted average cost per unit
    let dateAdded: Date

    init(coinId: String, amount: Double, averageBuyPrice: Double, dateAdded: Date = Date()) {
        self.coinId = coinId
        self.amount = amount
        self.averageBuyPrice = averageBuyPrice
        self.dateAdded = dateAdded
    }
}
