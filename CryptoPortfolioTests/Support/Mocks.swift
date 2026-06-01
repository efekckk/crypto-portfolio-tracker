import Foundation
@testable import CryptoPortfolio

// MARK: - Coin

final class MockCoinRepository: CoinRepository {
    var searchResult: [Coin] = []
    var marketsResult: [Coin] = []
    var chartResult: [ChartPoint] = []
    var errorToThrow: Error?
    private(set) var lastSearchQuery: String?
    private(set) var lastChartRequest: (coinId: String, range: PriceRange, currency: Currency)?

    func searchCoins(query: String) async throws -> [Coin] {
        lastSearchQuery = query
        if let errorToThrow { throw errorToThrow }
        return searchResult
    }
    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        if let errorToThrow { throw errorToThrow }
        return marketsResult
    }
    func chart(coinId: String, range: PriceRange, currency: Currency) async throws -> [ChartPoint] {
        lastChartRequest = (coinId, range, currency)
        if let errorToThrow { throw errorToThrow }
        return chartResult
    }
}

// MARK: - Portfolio

final class MockPortfolioRepository: PortfolioRepository {
    var storage: [String: Holding] = [:]

    func holdings() throws -> [Holding] {
        storage.values.sorted { $0.coinId < $1.coinId }
    }
    func holding(coinId: String) throws -> Holding? { storage[coinId] }
    func save(_ holding: Holding) throws { storage[holding.coinId] = holding }
    func remove(coinId: String) throws { storage[coinId] = nil }
}

// MARK: - Watchlist

final class MockWatchlistRepository: WatchlistRepository {
    var storage: [String: WatchItem] = [:]
    var errorToThrow: Error?

    func items() throws -> [WatchItem] {
        if let errorToThrow { throw errorToThrow }
        return storage.values.sorted { $0.addedAt < $1.addedAt }
    }
    func isWatched(coinId: String) throws -> Bool {
        if let errorToThrow { throw errorToThrow }
        return storage[coinId] != nil
    }
    func add(coinId: String) throws {
        if let errorToThrow { throw errorToThrow }
        if storage[coinId] == nil { storage[coinId] = WatchItem(coinId: coinId) }
    }
    func remove(coinId: String) throws {
        if let errorToThrow { throw errorToThrow }
        storage[coinId] = nil
    }
}

// MARK: - Alerts

final class MockAlertRepository: AlertRepository {
    var storage: [UUID: PriceAlert] = [:]
    var errorToThrow: Error?

    func alerts() throws -> [PriceAlert] {
        if let errorToThrow { throw errorToThrow }
        return Array(storage.values)
    }
    func alert(id: UUID) throws -> PriceAlert? {
        if let errorToThrow { throw errorToThrow }
        return storage[id]
    }
    func save(_ alert: PriceAlert) throws {
        if let errorToThrow { throw errorToThrow }
        storage[alert.id] = alert
    }
    func delete(id: UUID) throws {
        if let errorToThrow { throw errorToThrow }
        storage[id] = nil
    }
}

// MARK: - Notifications

final class SpyNotificationService: NotificationService {
    var authorizationResult: Bool = true
    private(set) var authorizationCalls: Int = 0
    private(set) var firings: [(title: String, body: String, identifier: String)] = []

    func requestAuthorizationIfNeeded() async -> Bool {
        authorizationCalls += 1
        return authorizationResult
    }
    func fire(title: String, body: String, identifier: String) async {
        firings.append((title, body, identifier))
    }
}
