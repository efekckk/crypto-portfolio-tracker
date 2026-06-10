import Foundation

/// Snapshot from the quote endpoint — current price + the user-actionable
/// buy/sell amount caps based on cash + existing holdings.
struct VirtualQuote: Equatable {
    let coinId: String
    let coinName: String
    let price: Double
    let fetchedAt: Date
    let maxBuyAmount: Double
    let maxSellAmount: Double
}
