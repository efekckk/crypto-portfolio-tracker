import XCTest
@testable import CryptoPortfolio

final class CurrencyFormatterCacheTests: XCTestCase {
    func test_repeatedFormatCalls_produceConsistentOutput() {
        let a = CurrencyFormatter.format(1234.5, currency: .usd, locale: Locale(identifier: "en_US"))
        let b = CurrencyFormatter.format(1234.5, currency: .usd, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(a, b)
    }

    func test_differentCurrencies_produceDifferentOutput() {
        let usd = CurrencyFormatter.format(100, currency: .usd, locale: Locale(identifier: "en_US"))
        let try_ = CurrencyFormatter.format(100, currency: .tryLira, locale: Locale(identifier: "tr_TR"))
        XCTAssertNotEqual(usd, try_)
    }

    func test_cacheReturnsSameFormatterInstance() {
        let f1 = CurrencyFormatter.cachedFormatter(currency: .usd, locale: Locale(identifier: "en_US"))
        let f2 = CurrencyFormatter.cachedFormatter(currency: .usd, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(f1 === f2, "Cache must return the same formatter instance for identical key")
    }
}
