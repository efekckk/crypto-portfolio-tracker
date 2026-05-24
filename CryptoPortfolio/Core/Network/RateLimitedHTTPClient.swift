import Foundation

/// Decorates an `HTTPClient`, consuming a token from the `RateLimiter` before each
/// request. Throws `APIError.rateLimited` when the bucket is empty, so callers never
/// have to remember to throttle.
final class RateLimitedHTTPClient: HTTPClient {
    private let inner: HTTPClient
    private let limiter: RateLimiter

    init(inner: HTTPClient, limiter: RateLimiter) {
        self.inner = inner
        self.limiter = limiter
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        guard await limiter.tryConsume() else { throw APIError.rateLimited }
        return try await inner.send(endpoint, as: type)
    }
}
