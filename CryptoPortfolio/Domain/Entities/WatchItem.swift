import Foundation

/// One starred coin in the user's watchlist.
struct WatchItem: Identifiable, Equatable {
    var id: String { coinId }
    let coinId: String
    let addedAt: Date

    init(coinId: String, addedAt: Date = Date()) {
        self.coinId = coinId
        self.addedAt = addedAt
    }
}
