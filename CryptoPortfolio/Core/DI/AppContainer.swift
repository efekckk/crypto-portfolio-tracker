import SwiftUI

/// Composition root: owns long-lived dependencies and builds use cases/view models.
/// Feature wiring is added in later phases.
final class AppContainer {
    let httpClient: HTTPClient
    let rateLimiter: RateLimiter
    let coreDataStack: CoreDataStack
    let analytics: AnalyticsService
    let crashReporter: CrashReporter

    init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        rateLimiter: RateLimiter = RateLimiter(),
        coreDataStack: CoreDataStack = CoreDataStack(),
        analytics: AnalyticsService = NoOpAnalytics(),
        crashReporter: CrashReporter = NoOpCrashReporter()
    ) {
        self.httpClient = httpClient
        self.rateLimiter = rateLimiter
        self.coreDataStack = coreDataStack
        self.analytics = analytics
        self.crashReporter = crashReporter
    }
}

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue = AppContainer()
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
