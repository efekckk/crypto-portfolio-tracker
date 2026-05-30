import XCTest
@testable import CryptoPortfolio

/// Records the endpoints sent and returns a canned Decodable per call.
private final class StubHTTPClient: HTTPClient {
    var responses: [Any] = []
    private(set) var sentEndpoints: [Endpoint] = []
    var errorToThrow: Error?

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        sentEndpoints.append(endpoint)
        if let errorToThrow { throw errorToThrow }
        return responses.removeFirst() as! T
    }
}

final class CoinRepositoryImplTests: XCTestCase {
    func test_searchCoins_mapsSearchResultsToCoins() async throws {
        let stub = StubHTTPClient()
        stub.responses = [
            CoinSearchResponseDTO(coins: [
                CoinSearchItemDTO(id: "bitcoin", name: "Bitcoin", symbol: "btc", thumb: nil, large: nil)
            ])
        ]
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.searchCoins(query: "bit")

        XCTAssertEqual(coins.map(\.id), ["bitcoin"])
        XCTAssertEqual(stub.sentEndpoints.first?.path, "search")
    }

    func test_searchCoins_returnsEmptyForBlankQueryWithoutCallingNetwork() async throws {
        let stub = StubHTTPClient()
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.searchCoins(query: "   ")

        XCTAssertTrue(coins.isEmpty)
        XCTAssertTrue(stub.sentEndpoints.isEmpty, "Blank query must not hit the network")
    }

    func test_markets_mapsMarketDTOsToCoins() async throws {
        let stub = StubHTTPClient()
        stub.responses = [
            [CoinMarketDTO(id: "bitcoin", symbol: "btc", name: "Bitcoin",
                           image: nil, currentPrice: 50000, priceChangePercentage24h: 1.0)]
        ]
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.markets(ids: ["bitcoin"], currency: .usd)

        XCTAssertEqual(coins.map(\.currentPrice), [50000])
        XCTAssertEqual(stub.sentEndpoints.first?.path, "coins/markets")
    }

    func test_markets_returnsEmptyForEmptyIdsWithoutCallingNetwork() async throws {
        let stub = StubHTTPClient()
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.markets(ids: [], currency: .usd)

        XCTAssertTrue(coins.isEmpty)
        XCTAssertTrue(stub.sentEndpoints.isEmpty)
    }

    func test_markets_propagatesNetworkError() async {
        let stub = StubHTTPClient()
        stub.errorToThrow = APIError.rateLimited
        let sut = CoinRepositoryImpl(httpClient: stub)

        do {
            _ = try await sut.markets(ids: ["bitcoin"], currency: .usd)
            XCTFail("Expected to throw")
        } catch let error as APIError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_chart_mapsResponseToChartPoints() async throws {
        let stub = StubHTTPClient()
        stub.responses = [
            MarketChartDTO(prices: [
                [1_700_000_000_000, 50_000],
                [1_700_003_600_000, 50_250]
            ])
        ]
        let sut = CoinRepositoryImpl(httpClient: stub)

        let points = try await sut.chart(coinId: "bitcoin", range: .d7, currency: .usd)

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points.first?.price, 50_000)
        XCTAssertEqual(stub.sentEndpoints.first?.path, "coins/bitcoin/market_chart")
    }
}
