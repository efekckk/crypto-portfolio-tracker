import Foundation

/// A QR-shareable portfolio item: a coin id + an amount.
struct PortfolioShareCode: Identifiable, Equatable {
    let coinId: String
    let amount: Double

    /// Stable identifier so SwiftUI `.sheet(item:)` can present the right sheet.
    /// Uses `|` because real coin ids contain `-` (e.g. `wrapped-bitcoin`).
    var id: String { "\(coinId)|\(amount)" }
}
