import XCTest
@testable import CryptoPortfolio

final class CurrencyFormatterTests: XCTestCase {
    func test_formatsUSDWithCorrectCurrencyCode() {
        let s = CurrencyFormatter.format(1234.5, currency: .usd, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(s.contains("1,234.50"), "Expected fixed two-digit fraction in '\(s)'")
        XCTAssertTrue(s.contains("$") || s.contains("USD"), "Expected USD marker in '\(s)'")
    }

    func test_formatsTRYWithCorrectCurrencyCode() {
        let s = CurrencyFormatter.format(1000, currency: .tryLira, locale: Locale(identifier: "tr_TR"))
        XCTAssertTrue(s.contains("₺") || s.contains("TRY") || s.contains("TL"),
                      "Expected TRY marker in '\(s)'")
    }

    func test_formatsPercentWithSignAndTwoFractionDigits() {
        XCTAssertEqual(CurrencyFormatter.formatPercent(2.5, locale: Locale(identifier: "en_US")), "+2.50%")
        XCTAssertEqual(CurrencyFormatter.formatPercent(-1.0, locale: Locale(identifier: "en_US")), "-1.00%")
        XCTAssertEqual(CurrencyFormatter.formatPercent(0, locale: Locale(identifier: "en_US")), "+0.00%")
    }
}
