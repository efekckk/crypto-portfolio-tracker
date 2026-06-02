import Foundation

/// How often a satisfied condition is allowed to fire.
enum Recurrence: Codable, Equatable {
    /// Fires once, then the alert deactivates itself.
    case oneShot
    /// Fires whenever the condition is true AND `seconds` have elapsed since
    /// the previous firing. Common presets: 3600 (1h), 21600 (6h), 86400 (24h).
    case cooldown(seconds: TimeInterval)
    /// Fires on each false→true transition of the condition.
    case onCrossing
}
