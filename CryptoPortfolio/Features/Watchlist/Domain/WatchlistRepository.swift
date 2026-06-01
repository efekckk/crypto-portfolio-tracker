import Foundation

/// Persistence for the user's watchlist (one entry per coinId).
protocol WatchlistRepository {
    func items() throws -> [WatchItem]
    func isWatched(coinId: String) throws -> Bool
    func add(coinId: String) throws
    func remove(coinId: String) throws
}
