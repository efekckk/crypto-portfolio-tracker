import XCTest
@testable import CryptoPortfolio

final class PortfolioShareCodecTests: XCTestCase {

    func test_encode_producesExpectedURLShape() {
        let code = PortfolioShareCode(coinId: "bitcoin", amount: 0.5)
        let s = PortfolioShareCodec.encode(code)
        XCTAssertTrue(s.hasPrefix("cptp://v1?"))
        XCTAssertTrue(s.contains("coin=bitcoin"))
        XCTAssertTrue(s.contains("amount=0.5"))
    }

    func test_encodeDecodeRoundTrip() throws {
        let original = PortfolioShareCode(coinId: "ethereum", amount: 12.345)
        let s = PortfolioShareCodec.encode(original)

        let decoded = try PortfolioShareCodec.decode(s)

        XCTAssertEqual(decoded, original)
    }

    func test_decode_rejectsWrongScheme() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("https://v1?coin=bitcoin&amount=1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .invalidScheme)
        }
    }

    func test_decode_rejectsWrongVersion() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v2?coin=bitcoin&amount=1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .invalidVersion)
        }
    }

    func test_decode_rejectsMissingCoin() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?amount=1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingCoin)
        }
    }

    func test_decode_rejectsMissingAmount() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
    }

    func test_decode_rejectsNonPositiveAmount() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin&amount=0")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin&amount=-1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
    }

    func test_decode_rejectsUnparseableAmount() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin&amount=abc")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
    }

    func test_decode_rejectsMalformedURL() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("not a url at all!! ")) { error in
            let err = error as? PortfolioShareCodecError
            XCTAssertTrue(err == .malformedURL || err == .invalidScheme,
                          "Expected malformedURL or invalidScheme, got \(String(describing: err))")
        }
    }

    func test_portfolioShareCode_isIdentifiableByCoinIdAndAmount() {
        let a = PortfolioShareCode(coinId: "bitcoin", amount: 1)
        let b = PortfolioShareCode(coinId: "bitcoin", amount: 1)
        let c = PortfolioShareCode(coinId: "bitcoin", amount: 2)
        XCTAssertEqual(a.id, b.id)
        XCTAssertNotEqual(a.id, c.id)
    }

    func test_portfolioShareCode_idDistinguishesHyphenatedCoinIds() {
        // Real coin ids contain hyphens (e.g. "wrapped-bitcoin"). The id separator
        // must not collide between distinct codes.
        let a = PortfolioShareCode(coinId: "wrapped-bitcoin", amount: 1.0)
        let b = PortfolioShareCode(coinId: "wrapped", amount: 1.0) // would collide on "-"
        XCTAssertNotEqual(a.id, b.id)
    }
}
