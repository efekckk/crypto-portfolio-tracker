import Foundation

/// Validates the user-chosen `AlertCondition` and persists a fresh alert with
/// the chosen `Recurrence`. Validation is per-variant:
/// - `.priceCrossing` / `.portfolioValue`: target must be strictly positive.
/// - `.percentChange` / `.portfolioPnLPercent`: threshold must be non-zero.
struct CreateAlertUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(condition: AlertCondition, recurrence: Recurrence) throws {
        try validate(condition)
        let alert = PriceAlert(
            id: UUID(),
            condition: condition,
            recurrence: recurrence,
            isActive: true,
            firedAt: nil,
            lastConditionResult: nil
        )
        try alertRepository.save(alert)
    }

    private func validate(_ condition: AlertCondition) throws {
        switch condition {
        case .priceCrossing(_, _, let target), .portfolioValue(_, let target):
            guard target > 0 else { throw AlertError.invalidPrice }
        case .percentChange(_, _, _, let threshold),
             .portfolioPnLPercent(_, let threshold):
            guard threshold != 0 else { throw AlertError.invalidThreshold }
        }
    }
}

extension CreateAlertUseCase {
    /// Backward-compat overload — kept so the v1.0 presentation/test surface
    /// (`createAlert(coinId:targetPrice:direction:)`) compiles unchanged.
    func callAsFunction(coinId: String, targetPrice: Double, direction: PriceAlert.Direction) throws {
        try self(
            condition: .priceCrossing(coinId: coinId, direction: direction, targetPrice: targetPrice),
            recurrence: .oneShot
        )
    }
}
