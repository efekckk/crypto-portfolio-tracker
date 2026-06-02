import SwiftUI

/// Composition root: owns long-lived dependencies and builds use cases/view models.
/// Feature wiring is added in later phases.
final class AppContainer {
    let httpClient: HTTPClient
    let rateLimiter: RateLimiter
    let coreDataStack: CoreDataStack
    let analytics: AnalyticsService
    let crashReporter: CrashReporter
    let notifications: NotificationService

    init(
        httpClient: HTTPClient? = nil,
        rateLimiter: RateLimiter = RateLimiter(),
        coreDataStack: CoreDataStack = CoreDataStack(),
        analytics: AnalyticsService = NoOpAnalytics(),
        crashReporter: CrashReporter = NoOpCrashReporter(),
        notifications: NotificationService = UserNotificationsService()
    ) {
        self.rateLimiter = rateLimiter
        self.httpClient = httpClient ?? RateLimitedHTTPClient(inner: URLSessionHTTPClient(), limiter: rateLimiter)
        self.coreDataStack = coreDataStack
        self.analytics = analytics
        self.crashReporter = crashReporter
        self.notifications = notifications
    }
    // MARK: - Repositories (lazy, share the container's infrastructure)

    internal(set) lazy var coinRepository: CoinRepository = CoinRepositoryImpl(httpClient: httpClient)
    private(set) lazy var portfolioRepository: PortfolioRepository = PortfolioRepositoryImpl(stack: coreDataStack)
    private(set) lazy var watchlistRepository: WatchlistRepository = WatchlistRepositoryImpl(stack: coreDataStack)
    private(set) lazy var alertRepository: AlertRepository = AlertRepositoryImpl(stack: coreDataStack)

    // MARK: - Use case factories

    func makeSearchCoinsUseCase() -> SearchCoinsUseCase {
        SearchCoinsUseCase(coinRepository: coinRepository)
    }

    func makeAddHoldingUseCase() -> AddHoldingUseCase {
        AddHoldingUseCase(portfolioRepository: portfolioRepository)
    }

    func makeRemoveHoldingUseCase() -> RemoveHoldingUseCase {
        RemoveHoldingUseCase(portfolioRepository: portfolioRepository)
    }

    func makeGetPortfolioSummaryUseCase() -> GetPortfolioSummaryUseCase {
        GetPortfolioSummaryUseCase(portfolioRepository: portfolioRepository, coinRepository: coinRepository)
    }

    func makeGetCoinChartUseCase() -> GetCoinChartUseCase {
        GetCoinChartUseCase(coinRepository: coinRepository)
    }

    func makeGetCoinMarketUseCase() -> GetCoinMarketUseCase {
        GetCoinMarketUseCase(coinRepository: coinRepository)
    }

    func makeGetWatchlistUseCase() -> GetWatchlistUseCase {
        GetWatchlistUseCase(watchlistRepository: watchlistRepository, coinRepository: coinRepository)
    }

    func makeToggleWatchlistUseCase() -> ToggleWatchlistUseCase {
        ToggleWatchlistUseCase(watchlistRepository: watchlistRepository)
    }

    func makeGetAlertsUseCase() -> GetAlertsUseCase {
        GetAlertsUseCase(alertRepository: alertRepository)
    }

    func makeCreateAlertUseCase() -> CreateAlertUseCase {
        CreateAlertUseCase(alertRepository: alertRepository)
    }

    func makeDeleteAlertUseCase() -> DeleteAlertUseCase {
        DeleteAlertUseCase(alertRepository: alertRepository)
    }

    func makeSetAlertActiveUseCase() -> SetAlertActiveUseCase {
        SetAlertActiveUseCase(alertRepository: alertRepository)
    }

    func makeEvaluateAlertsUseCase(currency: Currency = .default) -> EvaluateAlertsUseCase {
        EvaluateAlertsUseCase(
            alertRepository: alertRepository,
            coinRepository: coinRepository,
            portfolioRepository: portfolioRepository,
            currency: currency
        )
    }

    @MainActor
    @discardableResult
    func evaluateAndNotify(currency: Currency = .default) async -> Int {
        do {
            let firings = try await makeEvaluateAlertsUseCase(currency: currency)(now: Date())
            for firing in firings {
                await notifications.fire(
                    title: "Price alert",
                    body: "\(firing.alert.coinId.capitalized) crossed \(firing.alert.targetPrice)",
                    identifier: firing.alert.id.uuidString
                )
            }
            return firings.count
        } catch {
            return 0
        }
    }
}

private struct AppContainerKey: EnvironmentKey {
    /// Only used by SwiftUI previews / views without an injected container.
    /// Uses an in-memory store so previews never touch the on-disk database.
    /// Production injects its own container via `@State` in `CryptoPortfolioApp`.
    static let defaultValue = AppContainer(coreDataStack: CoreDataStack(inMemory: true))
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
