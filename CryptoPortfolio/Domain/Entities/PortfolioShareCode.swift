import Foundation

/// A QR-shareable portfolio item: a coin id + an amount.
struct PortfolioShareCode: Identifiable, Equatable {
    let coinId: String
    let amount: Double

    /// Stable identifier so SwiftUI `.sheet(item:)` can present the right sheet.
    var id: String { "\(coinId)-\(amount)" }
}
