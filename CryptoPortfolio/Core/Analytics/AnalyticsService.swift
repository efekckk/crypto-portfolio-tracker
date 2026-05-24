import Foundation

/// Abstraction over an analytics backend. Firebase slots in behind this later.
protocol AnalyticsService {
    func track(_ event: String, parameters: [String: Any])
}

extension AnalyticsService {
    func track(_ event: String) { track(event, parameters: [:]) }
}

/// Default implementation that does nothing (no backend wired yet).
struct NoOpAnalytics: AnalyticsService {
    func track(_ event: String, parameters: [String: Any]) {}
}
