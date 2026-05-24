import Foundation

/// Token-bucket limiter to respect the CoinGecko Demo tier (~30 requests/minute).
/// `now` is injectable for deterministic tests.
actor RateLimiter {
    private let capacity: Double
    private let refillInterval: TimeInterval // seconds to refill exactly one token
    private let now: () -> Date

    private var tokens: Double
    private var lastRefill: Date

    init(capacity: Int = 30, perInterval seconds: TimeInterval = 60, now: @escaping () -> Date = Date.init) {
        self.capacity = Double(capacity)
        self.refillInterval = seconds / Double(capacity)
        self.tokens = Double(capacity)
        self.now = now
        self.lastRefill = now()
    }

    /// Consumes one token if available. Returns false when the bucket is empty.
    func tryConsume() async -> Bool {
        refill()
        guard tokens >= 1 else { return false }
        tokens -= 1
        return true
    }

    private func refill() {
        let current = now()
        let elapsed = current.timeIntervalSince(lastRefill)
        guard elapsed > 0 else { return }
        tokens = min(capacity, tokens + elapsed / refillInterval)
        lastRefill = current
    }
}
