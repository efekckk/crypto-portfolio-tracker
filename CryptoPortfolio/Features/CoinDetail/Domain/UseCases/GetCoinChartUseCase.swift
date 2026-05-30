import Foundation

struct GetCoinChartUseCase {
    let coinRepository: CoinRepository

    func callAsFunction(coinId: String, range: PriceRange, currency: Currency) async throws -> [ChartPoint] {
        try await coinRepository.chart(coinId: coinId, range: range, currency: currency)
    }
}
