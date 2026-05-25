import Foundation

/// Read access to coin market data. Shared across Portfolio/Watchlist/CoinDetail.
protocol CoinRepository {
    func searchCoins(query: String) async throws -> [Coin]
    func markets(ids: [String], currency: Currency) async throws -> [Coin]
}
