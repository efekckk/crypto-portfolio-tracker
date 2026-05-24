import SwiftUI

/// Semantic color tokens backed by asset-catalog colors that adapt to dark/light.
/// Views use these instead of hard-coded colors.
enum Theme {
    static let accent = Color.accentColor
    static let positive = Color("Positive")
    static let negative = Color("Negative")

    /// Color for a signed change value: positive (>= 0) is green, negative is red.
    /// A flat 0% change is intentionally treated as positive (green).
    static func color(forChange value: Double) -> Color {
        value >= 0 ? positive : negative
    }
}
