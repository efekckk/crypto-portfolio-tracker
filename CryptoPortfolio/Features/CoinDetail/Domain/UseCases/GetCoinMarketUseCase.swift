import Foundation

struct GetCoinMarketUseCase {
    let coinRepository: CoinRepository

    func callAsFunction(coinId: String, currency: Currency) async throws -> Coin? {
        let coins = try await coinRepository.markets(ids: [coinId], currency: currency)
        return coins.first
    }
}
