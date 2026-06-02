import Foundation

/// A user-defined firing rule (polymorphic via `condition`) plus the runtime
/// state needed to enforce its `recurrence`.
struct PriceAlert: Identifiable, Equatable {
    let id: UUID
    var condition: AlertCondition
    var recurrence: Recurrence
    var isActive: Bool
    var firedAt: Date?
    /// Only meaningful for `.onCrossing`: the result of the previous
    /// evaluation pass. `nil` means "no previous pass" and is treated as
    /// "previously false" by the firing rule.
    var lastConditionResult: Bool?

    init(
        id: UUID = UUID(),
        condition: AlertCondition,
        recurrence: Recurrence,
        isActive: Bool = true,
        firedAt: Date? = nil,
        lastConditionResult: Bool? = nil
    ) {
        self.id = id
        self.condition = condition
        self.recurrence = recurrence
        self.isActive = isActive
        self.firedAt = firedAt
        self.lastConditionResult = lastConditionResult
    }
}

extension PriceAlert {
    /// Alias kept for backward compatibility with v1.0 call sites and tests.
    typealias Direction = AlertCondition.Direction

    /// Legacy convenience init — synthesises `.priceCrossing + .oneShot`.
    /// Required so the 154 v1.0 tests continue to compile and pass unchanged.
    init(
        id: UUID = UUID(),
        coinId: String,
        targetPrice: Double,
        direction: Direction,
        isActive: Bool = true,
        firedAt: Date? = nil
    ) {
        self.init(
            id: id,
            condition: .priceCrossing(coinId: coinId, direction: direction, targetPrice: targetPrice),
            recurrence: .oneShot,
            isActive: isActive,
            firedAt: firedAt,
            lastConditionResult: nil
        )
    }
}
