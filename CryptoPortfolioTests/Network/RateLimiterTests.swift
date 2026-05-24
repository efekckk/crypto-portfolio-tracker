import XCTest
@testable import CryptoPortfolio

final class RateLimiterTests: XCTestCase {
    func test_allowsUpToCapacityThenBlocks() async {
        var now = Date(timeIntervalSince1970: 0)
        let limiter = RateLimiter(capacity: 3, perInterval: 3, now: { now })

        let r1 = await limiter.tryConsume()
        let r2 = await limiter.tryConsume()
        let r3 = await limiter.tryConsume()
        let r4 = await limiter.tryConsume()

        XCTAssertEqual([r1, r2, r3], [true, true, true])
        XCTAssertFalse(r4)
    }

    func test_refillsOneTokenAfterRefillInterval() async {
        var now = Date(timeIntervalSince1970: 0)
        // capacity 2 over 2s => one token every 1s.
        let limiter = RateLimiter(capacity: 2, perInterval: 2, now: { now })

        _ = await limiter.tryConsume()
        _ = await limiter.tryConsume()
        let empty = await limiter.tryConsume()
        XCTAssertFalse(empty, "Bucket should be empty")

        now = now.addingTimeInterval(1) // refill exactly one token
        let refilled = await limiter.tryConsume()
        XCTAssertTrue(refilled, "One token should have refilled")
        let afterRefill = await limiter.tryConsume()
        XCTAssertFalse(afterRefill, "Only one token should refill")
    }

    func test_doesNotOverfillBeyondCapacity() async {
        var now = Date(timeIntervalSince1970: 0)
        let limiter = RateLimiter(capacity: 2, perInterval: 2, now: { now })

        now = now.addingTimeInterval(100) // long idle; must cap at capacity
        let r1 = await limiter.tryConsume()
        let r2 = await limiter.tryConsume()
        let r3 = await limiter.tryConsume()

        XCTAssertEqual([r1, r2], [true, true])
        XCTAssertFalse(r3)
    }
}
