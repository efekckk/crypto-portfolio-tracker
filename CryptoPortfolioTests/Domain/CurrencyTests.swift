import XCTest
@testable import CryptoPortfolio

final class CurrencyTests: XCTestCase {
    func test_codeMatchesCoinGeckoParameter() {
        XCTAssertEqual(Currency.usd.code, "usd")
        XCTAssertEqual(Currency.tryLira.code, "try")
    }

    func test_symbol() {
        XCTAssertEqual(Currency.usd.symbol, "$")
        XCTAssertEqual(Currency.tryLira.symbol, "₺")
    }

    func test_defaultIsUSD() {
        XCTAssertEqual(Currency.default, .usd)
    }
}
