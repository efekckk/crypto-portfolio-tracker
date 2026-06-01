import Foundation

/// An alert that crossed its threshold during evaluation.
struct AlertFiring: Equatable {
    let alert: PriceAlert
    let firedAt: Date
}
