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

// MARK: - Transitional accessors (removed in Task 11)
//
// These let v1.0 infrastructure (AlertRepositoryImpl, EvaluateAlertsUseCase,
// AlertRow, AppContainer.evaluateAndNotify) keep compiling while we land the
// polymorphic stack incrementally. Each one is the .priceCrossing projection;
// for non-.priceCrossing variants they silently return sentinel values
// ("" / 0). That's safe here because no legacy call site can reach a
// non-.priceCrossing alert until Tasks 3-11 incrementally replace those
// call sites with polymorphic equivalents.
extension PriceAlert {
    var coinId: String {
        if case .priceCrossing(let id, _, _) = condition { return id }
        // Portfolio variants don't have a single coinId; legacy callers
        // shouldn't be reading this field for them.
        return ""
    }
    var targetPrice: Double {
        if case .priceCrossing(_, _, let price) = condition { return price }
        return 0
    }
    var direction: AlertCondition.Direction {
        switch condition {
        case .priceCrossing(_, let dir, _), .percentChange(_, let dir, _, _),
             .portfolioValue(let dir, _), .portfolioPnLPercent(let dir, _):
            return dir
        }
    }
}
