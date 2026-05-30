import XCTest
@testable import CryptoPortfolio

@MainActor
final class CoinDetailUseCasesTests: XCTestCase {
    func test_getCoinChart_delegatesToRepository() async throws {
        let repo = MockCoinRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        repo.chartResult = [ChartPoint(id: 1_700_000_000_000, date: date, price: 50_000)]
        let sut = GetCoinChartUseCase(coinRepository: repo)

        let result = try await sut(coinId: "bitcoin", range: .d7, currency: .usd)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(repo.lastChartRequest?.coinId, "bitcoin")
        XCTAssertEqual(repo.lastChartRequest?.range, .d7)
        XCTAssertEqual(repo.lastChartRequest?.currency, .usd)
    }

    func test_getCoinMarket_returnsFirstMatchingCoin() async throws {
        let repo = MockCoinRepository()
        repo.marketsResult = [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        let sut = GetCoinMarketUseCase(coinRepository: repo)

        let coin = try await sut(coinId: "bitcoin", currency: .usd)

        XCTAssertEqual(coin?.id, "bitcoin")
    }

    func test_getCoinMarket_returnsNilWhenNoMatch() async throws {
        let repo = MockCoinRepository()
        repo.marketsResult = []
        let sut = GetCoinMarketUseCase(coinRepository: repo)

        let coin = try await sut(coinId: "missing", currency: .usd)

        XCTAssertNil(coin)
    }
}
