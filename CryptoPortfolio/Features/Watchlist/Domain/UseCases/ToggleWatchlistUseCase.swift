import Foundation

struct ToggleWatchlistUseCase {
    let watchlistRepository: WatchlistRepository

    func callAsFunction(coinId: String) throws {
        if try watchlistRepository.isWatched(coinId: coinId) {
            try watchlistRepository.remove(coinId: coinId)
        } else {
            try watchlistRepository.add(coinId: coinId)
        }
    }
}
