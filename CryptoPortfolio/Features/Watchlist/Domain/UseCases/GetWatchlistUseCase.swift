import Foundation

struct GetWatchlistUseCase {
    let watchlistRepository: WatchlistRepository
    let coinRepository: CoinRepository

    func callAsFunction(currency: Currency) async throws -> [Coin] {
        let items = try watchlistRepository.items()
        guard !items.isEmpty else { return [] }
        let ids = items.map(\.coinId)
        let coins = try await coinRepository.markets(ids: ids, currency: currency)
        let coinsById = Dictionary(coins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Preserve the original `WatchItem.addedAt` order returned by the repo.
        return ids.compactMap { coinsById[$0] }
    }
}
