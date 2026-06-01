import Foundation

struct GetWatchlistUseCase {
    let watchlistRepository: WatchlistRepository
    let coinRepository: CoinRepository

    func callAsFunction(currency: Currency) async throws -> [Coin] {
        let items = try watchlistRepository.items()
        guard !items.isEmpty else { return [] }
        return try await coinRepository.markets(ids: items.map(\.coinId), currency: currency)
    }
}
