import XCTest
@testable import CryptoPortfolio

final class CoinGeckoEndpointsTests: XCTestCase {
    func test_marketsEndpoint() {
        let endpoint = CoinGeckoEndpoints.markets(ids: ["bitcoin", "ethereum"], vsCurrency: "usd")

        XCTAssertEqual(endpoint.path, "coins/markets")
        let items = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value) })
        XCTAssertEqual(items["vs_currency"], "usd")
        XCTAssertEqual(items["ids"], "bitcoin,ethereum")
        XCTAssertEqual(items["price_change_percentage"], "24h,7d,30d")
    }

    func test_searchEndpoint() {
        let endpoint = CoinGeckoEndpoints.search(query: "bit")

        XCTAssertEqual(endpoint.path, "search")
        XCTAssertEqual(endpoint.queryItems.first(where: { $0.name == "query" })?.value, "bit")
    }

    func test_marketChartEndpoint() {
        let endpoint = CoinGeckoEndpoints.marketChart(coinId: "bitcoin", vsCurrency: "usd", days: "7")
        XCTAssertEqual(endpoint.path, "coins/bitcoin/market_chart")
        let items = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value) })
        XCTAssertEqual(items["vs_currency"], "usd")
        XCTAssertEqual(items["days"], "7")
    }

    func test_marketsEndpoint_requestsAllThreePercentWindows() {
        let endpoint = CoinGeckoEndpoints.markets(ids: ["bitcoin"], vsCurrency: "usd")
        let value = endpoint.queryItems.first(where: { $0.name == "price_change_percentage" })?.value
        XCTAssertEqual(value, "24h,7d,30d")
    }
}
