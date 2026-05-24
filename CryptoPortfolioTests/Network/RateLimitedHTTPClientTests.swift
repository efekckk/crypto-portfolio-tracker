import XCTest
@testable import CryptoPortfolio

private struct Ping: Decodable, Equatable { let ok: Bool }

private final class SpyHTTPClient: HTTPClient {
    private(set) var callCount = 0
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        callCount += 1
        return Ping(ok: true) as! T
    }
}

final class RateLimitedHTTPClientTests: XCTestCase {
    func test_send_forwardsToInnerWhenTokenAvailable() async throws {
        let now = Date(timeIntervalSince1970: 0)
        let spy = SpyHTTPClient()
        let sut = RateLimitedHTTPClient(
            inner: spy,
            limiter: RateLimiter(capacity: 3, perInterval: 60, now: { now })
        )

        let result = try await sut.send(Endpoint(path: "ping"), as: Ping.self)

        XCTAssertEqual(result, Ping(ok: true))
        XCTAssertEqual(spy.callCount, 1)
    }

    func test_send_throwsRateLimitedAndDoesNotCallInnerWhenNoToken() async {
        let now = Date(timeIntervalSince1970: 0)
        let spy = SpyHTTPClient()
        // capacity 1, frozen clock => second call has no token.
        let sut = RateLimitedHTTPClient(
            inner: spy,
            limiter: RateLimiter(capacity: 1, perInterval: 60, now: { now })
        )

        _ = try? await sut.send(Endpoint(path: "ping"), as: Ping.self) // consumes the only token

        do {
            _ = try await sut.send(Endpoint(path: "ping"), as: Ping.self)
            XCTFail("Expected to throw .rateLimited")
        } catch let error as APIError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Expected APIError.rateLimited, got \(error)")
        }
        XCTAssertEqual(spy.callCount, 1, "Inner must NOT be called when throttled")
    }
}
