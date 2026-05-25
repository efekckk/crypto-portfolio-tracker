import Foundation

struct SearchCoinsUseCase {
    let coinRepository: CoinRepository

    func callAsFunction(_ query: String) async throws -> [Coin] {
        try await coinRepository.searchCoins(query: query)
    }
}
