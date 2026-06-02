# Advanced Alerts — Design Spec

- **Date:** 2026-06-02
- **Status:** Approved (design); implementation plan pending
- **Scope:** iOS app (v1.1 feature on top of v1.0 main).

## 1. Purpose

Extend v1.0's local price-alert system from a single-shape `(coinId, targetPrice,
above/below)` model to a polymorphic alert system with three new condition types
and per-alert recurrence modes. The user can now express:

- **Price threshold** — current behavior (coin price above/below a target).
- **Percent change** — coin moved ±X % over a 24h / 7d / 30d window.
- **Portfolio value** — total portfolio value above/below a target.
- **Portfolio P/L percent** — overall portfolio P/L above/below a threshold.

…and choose, per alert, whether it fires **once**, **repeatedly with a cooldown**,
or **on each fresh crossing** of the condition.

## 2. Goals & non-goals

**Goals**
- Polymorphic `AlertCondition` covering the four variants above.
- `Recurrence` enum: `.oneShot`, `.cooldown(seconds)`, `.onCrossing`.
- Backward compatibility for v1.0 alerts already on disk and for the v1.0
  programmatic API used by the existing 154-test alert suite.
- Single consolidated network round trip per evaluation pass, regardless of
  alert-type mix.
- L10n (tr + en) for every new user-facing string.

**Non-goals (this cycle)**
- Custom percent windows (only 24h / 7d / 30d).
- Push pipeline / server-side evaluation.
- Multi-coin compound conditions ("BTC AND ETH").
- Volume / market-cap / news triggers.
- CoinDetail-style chart-overlay visualisation of where an alert would fire.

## 3. Decisions

| Topic | Decision |
| --- | --- |
| Condition shape | Polymorphic `AlertCondition` Codable enum, persisted as JSON |
| Recurrence | Per-alert; user-selected: `.oneShot` / `.cooldown(seconds)` / `.onCrossing` |
| Percent windows | 24h, 7d, 30d only (CoinGecko `price_change_percentage` param) |
| Portfolio metric | Two variants: `portfolioValue` and `portfolioPnLPercent` |
| Storage | Add `conditionJSON`/`recurrenceJSON`/`lastConditionResult` columns; keep legacy columns nullable for backward compat |
| Migration | Core Data lightweight (model v2); existing rows decode as `.priceCrossing + .oneShot` |
| API change | `CreateAlertUseCase` gains `(condition:recurrence:)` overload; old `(coinId:targetPrice:direction:)` kept as convenience |
| CoinDetail shortcut | `initialCoin` still works; skips type chooser, defaults to `.priceCrossing` form |

## 4. Domain model

### 4.1 `AlertCondition` (Codable, Equatable)

```swift
enum AlertCondition: Codable, Equatable {
    case priceCrossing(coinId: String, direction: Direction, targetPrice: Double)
    case percentChange(coinId: String, direction: Direction, window: PercentWindow, threshold: Double)
    case portfolioValue(direction: Direction, threshold: Double)
    case portfolioPnLPercent(direction: Direction, threshold: Double)

    enum Direction: String, Codable { case above, below }
    enum PercentWindow: String, Codable, CaseIterable { case h24, d7, d30 }

    /// Coin ids needed to evaluate this condition. `nil` means
    /// "all currently-held coins" (portfolio variants).
    var requiredCoinIds: Set<String>? {
        switch self {
        case .priceCrossing(let id, _, _), .percentChange(let id, _, _, _): return [id]
        case .portfolioValue, .portfolioPnLPercent: return nil
        }
    }
}
```

### 4.2 `Recurrence` (Codable, Equatable)

```swift
enum Recurrence: Codable, Equatable {
    case oneShot                          // fire once; isActive then becomes false
    case cooldown(seconds: TimeInterval)  // off / 1h / 6h / 24h presets in UI
    case onCrossing                       // fire on each false→true transition
}
```

### 4.3 `PriceAlert` (refactored entity)

```swift
struct PriceAlert: Identifiable, Equatable {
    let id: UUID
    var condition: AlertCondition
    var recurrence: Recurrence
    var isActive: Bool
    var firedAt: Date?              // last fire timestamp
    var lastConditionResult: Bool?  // only used by .onCrossing
}
```

Top-level `coinId/targetPrice/direction` are removed; they live inside
`condition.priceCrossing` (or other variants).

### 4.4 Backward-compat extension

```swift
extension PriceAlert {
    typealias Direction = AlertCondition.Direction

    /// Legacy convenience init used by the v1.0 test suite.
    /// Synthesises `.priceCrossing + .oneShot`.
    init(coinId: String, targetPrice: Double, direction: Direction,
         isActive: Bool = true, firedAt: Date? = nil) {
        self.init(
            id: UUID(),
            condition: .priceCrossing(coinId: coinId, direction: direction, targetPrice: targetPrice),
            recurrence: .oneShot,
            isActive: isActive, firedAt: firedAt, lastConditionResult: nil
        )
    }
}
```

This preserves every existing `PriceAlert(...)` call site byte-for-byte.

### 4.5 `Coin` entity additions

```swift
var priceChangePercentage7d: Double?
var priceChangePercentage30d: Double?
```

Both optional, default `nil`. The existing `Coin(...)` callers continue to
compile (Phase 3 stats-fields pattern).

## 5. Data layer

### 5.1 CDAlert schema v2 (Core Data lightweight migration)

| Attribute | Change |
| --- | --- |
| `id: UUID` | unchanged |
| `coinId: String` | **now optional** (nil for portfolio variants) |
| `targetPrice: Double` | unchanged (sentinel 0 for non-`.priceCrossing`) |
| `direction: String` | unchanged (sentinel "above" for non-`.priceCrossing`) |
| `isActive: Bool` | unchanged |
| `firedAt: Date?` | unchanged |
| `conditionJSON: String?` | **NEW**, canonical condition source |
| `recurrenceJSON: String?` | **NEW**, canonical recurrence source |
| `lastConditionResult: Bool?` | **NEW**, NSNumber-backed optional Bool |

Lightweight migration: Core Data infers the schema deltas automatically.

### 5.2 `AlertRepositoryImpl.toDomain` mapping

1. If `conditionJSON != nil` → JSON-decode → `AlertCondition`.
2. Else (legacy row): synthesise `.priceCrossing(coinId: entity.coinId!, direction: from rawValue, targetPrice: entity.targetPrice)`. Force-unwrap safe because legacy schema required `coinId`.
3. If `recurrenceJSON != nil` → JSON-decode → `Recurrence`; else `.oneShot`.
4. `lastConditionResult` → `entity.lastConditionResult?.boolValue`.

### 5.3 `AlertRepositoryImpl.save` mapping

- Always JSON-encode `condition` and `recurrence` into the new columns
  (canonical source).
- For `.priceCrossing` variants: also mirror `coinId/targetPrice/direction` into
  the legacy columns (debug visibility + forward query).
- For other variants: leave legacy columns at sentinel (`nil/0/"above"`).
- `lastConditionResult` boxed into `NSNumber?`.

### 5.4 CoinGecko / pipeline updates

- `CoinGeckoEndpoints.markets`: query param `price_change_percentage` changes
  from `"24h"` to `"24h,7d,30d"`.
- `CoinMarketDTO`: add
  ```swift
  let priceChangePercentage7dInCurrency: Double?
  let priceChangePercentage30dInCurrency: Double?
  ```
  (CoinGecko's `_in_currency`-suffixed fields).
- `CoinMapper.map(_:CoinMarketDTO)`: map them to
  `Coin.priceChangePercentage7d/30d`.

## 6. Use cases

### 6.1 `CreateAlertUseCase` (signature change)

```swift
struct CreateAlertUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(condition: AlertCondition, recurrence: Recurrence) throws {
        try validate(condition)
        let alert = PriceAlert(id: UUID(), condition: condition,
                               recurrence: recurrence, isActive: true,
                               firedAt: nil, lastConditionResult: nil)
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

// Backward compat for the v1.0 test suite:
extension CreateAlertUseCase {
    func callAsFunction(coinId: String, targetPrice: Double,
                        direction: PriceAlert.Direction) throws {
        try self(condition: .priceCrossing(coinId: coinId,
                                           direction: direction,
                                           targetPrice: targetPrice),
                 recurrence: .oneShot)
    }
}
```

`AlertError` gains `.invalidThreshold` (existing `.invalidPrice` stays for v1 compat).

### 6.2 `EvaluateAlertsUseCase` (rewrite)

New dependency: `portfolioRepository: PortfolioRepository`.

```swift
func callAsFunction(now: Date = Date()) async throws -> [AlertFiring] {
    let active = try alertRepository.alerts().filter { $0.isActive }
    guard !active.isEmpty else { return [] }

    // 1) Collect required data sets.
    var coinIds: Set<String> = []
    for alert in active {
        coinIds.formUnion(alert.condition.requiredCoinIds ?? [])
    }
    let needsPortfolio = active.contains { alert in
        if case .portfolioValue = alert.condition { return true }
        if case .portfolioPnLPercent = alert.condition { return true }
        return false
    }
    var holdings: [Holding] = []
    if needsPortfolio {
        holdings = try portfolioRepository.holdings()
        coinIds.formUnion(holdings.map(\.coinId))
    }

    // 2) Single consolidated markets call.
    let coins = coinIds.isEmpty ? []
        : try await coinRepository.markets(ids: Array(coinIds), currency: currency)
    let coinsById = Dictionary(coins.map { ($0.id, $0) },
                               uniquingKeysWith: { first, _ in first })

    // 3) Portfolio summary (only when needed).
    let summary: PortfolioSummary? = needsPortfolio
        ? buildSummary(holdings: holdings, coinsById: coinsById)
        : nil

    // 4) Per-alert eval + fire-decision + state update.
    var firings: [AlertFiring] = []
    for alert in active {
        guard let conditionTrue = evaluate(alert.condition,
                                           coinsById: coinsById, summary: summary)
        else { continue } // missing data; skip without state change

        var updated = alert
        if case .onCrossing = alert.recurrence {
            updated.lastConditionResult = conditionTrue
        }
        if shouldFire(alert, conditionTrue: conditionTrue, now: now) {
            updated.firedAt = now
            if case .oneShot = alert.recurrence { updated.isActive = false }
            firings.append(AlertFiring(alert: updated, firedAt: now))
        }
        if updated != alert {
            try alertRepository.save(updated)
        }
    }
    return firings
}
```

**`evaluate(...)` per variant:**
- `.priceCrossing(coinId, .above, t)` → `coinsById[coinId]?.currentPrice ?? nil` then `≥ t`.
- `.priceCrossing(_, .below, _)` → `≤ t`.
- `.percentChange(coinId, dir, window, threshold)` → pick `priceChangePercentage{24h|7d|30d}`; nil if field is nil; compare with threshold per direction.
- `.portfolioValue(dir, t)` → `summary?.totalValue` vs `t`.
- `.portfolioPnLPercent(dir, t)` → `summary?.percentPnL` vs `t`.

**`shouldFire(...)` per recurrence (assuming condition is true):**

| Recurrence | Predicate |
| --- | --- |
| `.oneShot` | `alert.firedAt == nil` |
| `.cooldown(seconds)` | `alert.firedAt == nil OR now.timeIntervalSince(firedAt) ≥ seconds` |
| `.onCrossing` | `alert.lastConditionResult != true` (nil treated as "previously false") |

## 7. Presentation

### 7.1 CreateAlert navigation flow

```
CreateAlertView (root)
└── AlertTypeChooserView
    ├── Price threshold     → CoinSearchPickerView → PriceAlertFormView
    ├── Percent change       → CoinSearchPickerView → PercentAlertFormView
    ├── Portfolio value      → PortfolioAlertFormView (value mode)
    └── Portfolio P/L        → PortfolioAlertFormView (percent mode)
```

- `RecurrencePickerView` is a shared inline section inside each form: One shot /
  Cooldown (1h, 6h, 24h presets) / On crossing.
- `initialCoin` (CoinDetail shortcut from Phase 7) bypasses the chooser and pushes
  straight to `PriceAlertFormView` with the coin pre-set.

### 7.2 ViewModels (one per form)

- `CreatePriceAlertViewModel` (coin, direction, targetPrice, recurrence)
- `CreatePercentAlertViewModel` (coin, window, direction, threshold, recurrence)
- `CreatePortfolioAlertViewModel` (metric: value|pnlPercent, direction, threshold, recurrence)

All depend on `CreateAlertUseCase`. Each exposes a `save() async -> Bool` and an
optional `saveError: String?` for inline error display.

### 7.3 `AlertRow` polymorphic display

| Variant | Icon | Primary text | Secondary text |
| --- | --- | --- | --- |
| `.priceCrossing` | `arrow.up.circle.fill` / `down` | `{coin} {direction-symbol} {price}` | recurrence label |
| `.percentChange` | `chart.line.uptrend.xyaxis` / `downtrend` | `{coin} {±percent}% ({window})` | recurrence label |
| `.portfolioValue` | `briefcase.fill` | `Portfolio {direction-symbol} {amount}` | recurrence label |
| `.portfolioPnLPercent` | `chart.pie.fill` | `P/L {direction-symbol} {percent}%` | recurrence label |

`firedAt != nil` → trailing "Fired" badge. Active toggle behaviour unchanged
(Phase 5 + Phase 7 re-arm semantics).

### 7.4 Notification body formatter

Single source of truth in `Core/Notifications/AlertNotificationFormatter.swift`:

```swift
enum AlertNotificationFormatter {
    static func bodyKey(for firing: AlertFiring,
                        currency: Currency) -> String
}
```

Returns a fully formatted `String`. Used by both `AlertsViewModel.evaluateNow`
and `AppContainer.evaluateAndNotify` (BGTask handler).

Body templates (English defaults):
- `.priceCrossing` → `"{coin} crossed {price}"`
- `.percentChange` → `"{coin} moved {percent}% in {window}"`
- `.portfolioValue` → `"Portfolio total reached {amount}"`
- `.portfolioPnLPercent` → `"Portfolio P/L is now {percent}%"`

`{coin}` resolves to the coin's known name when available
(via the in-flight markets fetch); otherwise the coinId capitalised.

### 7.5 New L10n keys (~15)

- `alerts.type.{priceCrossing,percentChange,portfolioValue,portfolioPnLPercent}`
- `alerts.recurrence.{oneShot,cooldown,onCrossing}`
- `alerts.cooldown.{1h,6h,24h}`
- `alerts.window.{h24,d7,d30}`
- `alerts.metric.{value,pnlPercent}`
- `alerts.form.{type,direction,threshold,window,recurrence,metric}`
- `alerts.notification.body.{priceCrossing,percentChange,portfolioValue,portfolioPnLPercent}` (with `%@`/`%d` interpolation)

## 8. Testing strategy

### 8.1 Domain layer
- `AlertCondition` Codable round-trip per variant (4 tests).
- `Recurrence` Codable round-trip per variant (3 tests).
- `requiredCoinIds` semantics (coin variants vs portfolio variants).

### 8.2 Data layer
- Legacy CDAlert row decoding (no JSON) → `.priceCrossing + .oneShot` (1 test).
- Save round-trip per AlertCondition × Recurrence (12 combos, asserted with
  representative subset of 6).
- 7d/30d `CoinMarketDTO` decoding (2 tests).
- `CoinMapper` 7d/30d field mapping (2 tests).

### 8.3 Use cases
- `CreateAlertUseCase`: validation per variant (priceCrossing/portfolioValue
  rejects ≤0; percentChange/portfolioPnLPercent rejects 0). Backward-compat
  overload still produces `.priceCrossing + .oneShot`.
- `EvaluateAlertsUseCase`:
  - Happy path per variant × recurrence (≥12 tests).
  - Cooldown boundary (just before / just after).
  - `.onCrossing` transition algorithm (false→true fires; true→true doesn't;
    true→false→true fires again).
  - Missing data (coin not in markets / no holdings) → no state change.
  - Mixed-type single evaluation pass → each evaluated independently.
  - Consolidated network call (assert single `markets` call regardless of mix).

### 8.4 Presentation
- Each form ViewModel: validation + happy-path save (via mocked use case).
- CoinDetail `initialCoin` shortcut still routes to `PriceAlertFormView` with
  coin pre-set.
- `AlertNotificationFormatter` body output per variant.

### 8.5 Backward compatibility
- All v1.0 alert tests (≈30 touching `PriceAlert`) continue to pass without
  modification, thanks to the convenience init and `CreateAlertUseCase`
  overload.

## 9. Phasing (for the implementation plan)

The plan sequences the spec so something works at every checkpoint:

1. **Domain core** — `AlertCondition`, `Recurrence`, refactored `PriceAlert` +
   convenience init, `Coin` field additions. All existing tests recompile.
2. **Data layer** — CDAlert schema v2 + repo mapping (both legacy and
   JSON paths) + DTO/mapper updates.
3. **EvaluateAlertsUseCase rewrite** — polymorphic evaluation + recurrence
   state machine + consolidated fetch. Single-call assertion.
4. **`CreateAlertUseCase` + form ViewModels** — new signature + overload + 3
   form VMs.
5. **Presentation** — `AlertTypeChooserView` + 3 form views + `RecurrencePicker`
   + polymorphic `AlertRow` + notification formatter.
6. **L10n + final wiring** — keys + CoinDetail `initialCoin` shortcut path +
   simulator launch + screenshot.

## 10. Out of scope (future)

- Compound conditions (multiple coins / AND-OR).
- Volume / market-cap / news triggers.
- Push pipeline.
- Custom percent windows beyond 24h / 7d / 30d.
- Cross-device sync of alerts (will follow whenever iCloud sync ships).
