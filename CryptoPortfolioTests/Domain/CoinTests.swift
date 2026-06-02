import XCTest
@testable import CryptoPortfolio

final class CoinTests: XCTestCase {
    func test_init_withoutPercentFields_defaultsToNil() {
        let coin = Coin(id: "btc", symbol: "btc", name: "Bitcoin")
        XCTAssertNil(coin.priceChangePercentage7d)
        XCTAssertNil(coin.priceChangePercentage30d)
    }

    func test_init_storesPercentFields() {
        let coin = Coin(
            id: "btc", symbol: "btc", name: "Bitcoin",
            priceChangePercentage7d: -3.5,
            priceChangePercentage30d: 12.1
        )
        XCTAssertEqual(coin.priceChangePercentage7d, -3.5)
        XCTAssertEqual(coin.priceChangePercentage30d, 12.1)
    }
}
