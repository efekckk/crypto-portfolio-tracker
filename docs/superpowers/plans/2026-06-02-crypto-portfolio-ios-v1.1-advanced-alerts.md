# Advanced Alerts (v1.1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the v1.0 alerts system from a single `(coinId, targetPrice, above/below)` shape to a polymorphic `AlertCondition` (price crossing / percent change / portfolio value / portfolio P/L %) with per-alert `Recurrence` (one-shot / cooldown / on-crossing), preserving backward compatibility with all 154 v1.0 tests.

**Architecture:** Clean Architecture preserved: Domain owns the new `AlertCondition`/`Recurrence` Codable enums and the refactored `PriceAlert`; Data persists them as JSON columns on a v2 Core Data model with lightweight migration plus legacy fallback decoding; `EvaluateAlertsUseCase` gains a `PortfolioRepository` dependency and a polymorphic evaluation pipeline that consolidates a single market fetch per pass; Presentation forks into a type chooser → three form view-models (price / percent / portfolio), with a shared `RecurrencePickerView` and a polymorphic `AlertRow`.

**Tech Stack:** Swift 5 mode, SwiftUI, iOS 16+, Core Data (lightweight migration, JSON-encoded polymorphic columns), Swift Concurrency, XCTest. No new third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-06-02-crypto-portfolio-ios-advanced-alerts-design.md`

---

## File Structure

### New files

| Path | Responsibility |
| --- | --- |
| `CryptoPortfolio/Domain/Entities/AlertCondition.swift` | Polymorphic Codable enum with `Direction` and `PercentWindow` |
| `CryptoPortfolio/Domain/Entities/Recurrence.swift` | Codable enum: `.oneShot` / `.cooldown(seconds:)` / `.onCrossing` |
| `CryptoPortfolio/Core/Notifications/AlertNotificationFormatter.swift` | Single source of truth for notification title+body per condition variant |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertTypeChooserView.swift` | First step of the new Create flow — picks the condition type |
| `CryptoPortfolio/Features/Alerts/Presentation/RecurrencePickerView.swift` | Reusable inline Recurrence section used by all three forms |
| `CryptoPortfolio/Features/Alerts/Presentation/PriceAlertFormView.swift` | Form for `.priceCrossing` (refactor of v1.0 `AlertConditionView`) |
| `CryptoPortfolio/Features/Alerts/Presentation/CreatePriceAlertViewModel.swift` | VM behind `PriceAlertFormView` |
| `CryptoPortfolio/Features/Alerts/Presentation/PercentAlertFormView.swift` | Form for `.percentChange` |
| `CryptoPortfolio/Features/Alerts/Presentation/CreatePercentAlertViewModel.swift` | VM behind `PercentAlertFormView` |
| `CryptoPortfolio/Features/Alerts/Presentation/PortfolioAlertFormView.swift` | Form for `.portfolioValue` and `.portfolioPnLPercent` |
| `CryptoPortfolio/Features/Alerts/Presentation/CreatePortfolioAlertViewModel.swift` | VM behind `PortfolioAlertFormView` |
| `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio_v2.xcdatamodel/contents` | Versioned model v2 (CDAlert schema additions) |
| `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/.xccurrentversion` | Pointer to v2 |

### Files modified

| Path | Change |
| --- | --- |
| `CryptoPortfolio/Domain/Entities/PriceAlert.swift` | Refactor to hold `condition`/`recurrence`/`lastConditionResult`; backward-compat init |
| `CryptoPortfolio/Domain/Entities/Coin.swift` | Add `priceChangePercentage7d` / `30d` optional doubles |
| `CryptoPortfolio/Features/Alerts/Data/AlertRepositoryImpl.swift` | JSON encode/decode with legacy fallback |
| `CryptoPortfolio/Core/Data/Coin/CoinMarketDTO.swift` | Add 7d/30d in-currency fields |
| `CryptoPortfolio/Core/Data/Coin/CoinMapper.swift` | Wire 7d/30d into `Coin` |
| `CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift` | `price_change_percentage=24h,7d,30d` |
| `CryptoPortfolio/Features/Alerts/Domain/UseCases/CreateAlertUseCase.swift` | New `(condition:recurrence:)` signature + legacy overload + `.invalidThreshold` |
| `CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift` | Polymorphic rewrite + portfolio dependency |
| `CryptoPortfolio/Core/DI/AppContainer.swift` | Inject `portfolioRepository` into evaluator; use `AlertNotificationFormatter` in `evaluateAndNotify` |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertRow.swift` | Polymorphic display per condition variant |
| `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift` | Root routes through `AlertTypeChooserView`; `initialCoin` still shortcuts to `PriceAlertFormView` |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertConditionView.swift` | **Delete** (replaced by `PriceAlertFormView`) |
| `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift` | Reduce to just the search step (forms own their own VMs) |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift` | Notification body via `AlertNotificationFormatter` |
| `CryptoPortfolio/Resources/Localizable.xcstrings` | ~15 new keys (tr + en) |
| `project.yml` | (Only touched if XcodeGen needs explicit `optionalCoreDataModelGen` flag; verify) |

---

## Task 1: Domain — `AlertCondition` and `Recurrence`

**Files:**
- Create: `CryptoPortfolio/Domain/Entities/AlertCondition.swift`
- Create: `CryptoPortfolio/Domain/Entities/Recurrence.swift`
- Test: `CryptoPortfolioTests/Alerts/Domain/AlertConditionTests.swift`
- Test: `CryptoPortfolioTests/Alerts/Domain/RecurrenceTests.swift`

- [ ] **Step 1: Write the failing tests for `AlertCondition`**

Create `CryptoPortfolioTests/Alerts/Domain/AlertConditionTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

final class AlertConditionTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func test_priceCrossing_codable_roundTrip() throws {
        let original: AlertCondition = .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_percentChange_codable_roundTrip() throws {
        let original: AlertCondition = .percentChange(coinId: "ethereum", direction: .below, window: .d7, threshold: -5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_portfolioValue_codable_roundTrip() throws {
        let original: AlertCondition = .portfolioValue(direction: .above, threshold: 100_000)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_portfolioPnLPercent_codable_roundTrip() throws {
        let original: AlertCondition = .portfolioPnLPercent(direction: .below, threshold: -10)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AlertCondition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_requiredCoinIds_priceCrossing_isSingleton() {
        let c: AlertCondition = .priceCrossing(coinId: "btc", direction: .above, targetPrice: 1)
        XCTAssertEqual(c.requiredCoinIds, ["btc"])
    }

    func test_requiredCoinIds_percentChange_isSingleton() {
        let c: AlertCondition = .percentChange(coinId: "eth", direction: .above, window: .h24, threshold: 1)
        XCTAssertEqual(c.requiredCoinIds, ["eth"])
    }

    func test_requiredCoinIds_portfolioVariants_areNil() {
        XCTAssertNil(AlertCondition.portfolioValue(direction: .above, threshold: 1).requiredCoinIds)
        XCTAssertNil(AlertCondition.portfolioPnLPercent(direction: .above, threshold: 1).requiredCoinIds)
    }
}
```

- [ ] **Step 2: Write the failing tests for `Recurrence`**

Create `CryptoPortfolioTests/Alerts/Domain/RecurrenceTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

final class RecurrenceTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func test_oneShot_roundTrip() throws {
        let data = try encoder.encode(Recurrence.oneShot)
        XCTAssertEqual(try decoder.decode(Recurrence.self, from: data), .oneShot)
    }

    func test_cooldown_roundTrip_preservesInterval() throws {
        let data = try encoder.encode(Recurrence.cooldown(seconds: 3600))
        XCTAssertEqual(try decoder.decode(Recurrence.self, from: data), .cooldown(seconds: 3600))
    }

    func test_onCrossing_roundTrip() throws {
        let data = try encoder.encode(Recurrence.onCrossing)
        XCTAssertEqual(try decoder.decode(Recurrence.self, from: data), .onCrossing)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:
```bash
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -20
```
Expected: COMPILE FAILURE — `AlertCondition` and `Recurrence` not found.

- [ ] **Step 4: Create `AlertCondition.swift`**

Create `CryptoPortfolio/Domain/Entities/AlertCondition.swift`:

```swift
import Foundation

/// A user-defined firing rule. Polymorphic so we can express coin-price,
/// percent-change, and portfolio-level conditions in one column.
enum AlertCondition: Codable, Equatable {
    case priceCrossing(coinId: String, direction: Direction, targetPrice: Double)
    case percentChange(coinId: String, direction: Direction, window: PercentWindow, threshold: Double)
    case portfolioValue(direction: Direction, threshold: Double)
    case portfolioPnLPercent(direction: Direction, threshold: Double)

    enum Direction: String, Codable { case above, below }
    enum PercentWindow: String, Codable, CaseIterable { case h24, d7, d30 }

    /// Coin ids needed to evaluate this condition. `nil` means
    /// "all currently-held coins" (portfolio variants resolve their coin set
    /// from the user's holdings at evaluation time).
    var requiredCoinIds: Set<String>? {
        switch self {
        case .priceCrossing(let id, _, _), .percentChange(let id, _, _, _):
            return [id]
        case .portfolioValue, .portfolioPnLPercent:
            return nil
        }
    }
}
```

- [ ] **Step 5: Create `Recurrence.swift`**

Create `CryptoPortfolio/Domain/Entities/Recurrence.swift`:

```swift
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
```

- [ ] **Step 6: Run tests to verify they pass**

Run:
```bash
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/AlertConditionTests \
       -only-testing:CryptoPortfolioTests/RecurrenceTests 2>&1 | tail -20
```
Expected: PASS — 10/10 tests green.

- [ ] **Step 7: Commit**

```bash
git add CryptoPortfolio/Domain/Entities/AlertCondition.swift \
        CryptoPortfolio/Domain/Entities/Recurrence.swift \
        CryptoPortfolioTests/Alerts/Domain/AlertConditionTests.swift \
        CryptoPortfolioTests/Alerts/Domain/RecurrenceTests.swift \
        project.yml CryptoPortfolio.xcodeproj 2>/dev/null || true
git add -A CryptoPortfolio CryptoPortfolioTests
git commit -m "feat(alerts): introduce polymorphic AlertCondition and Recurrence

Codable enums with associated values; JSON round-trip covered per variant.
requiredCoinIds drives the consolidated markets fetch in EvaluateAlertsUseCase.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Domain — Refactor `PriceAlert` (backward-compatible)

**Files:**
- Modify: `CryptoPortfolio/Domain/Entities/PriceAlert.swift`
- Test: `CryptoPortfolioTests/Alerts/Domain/PriceAlertTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Alerts/Domain/PriceAlertTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

final class PriceAlertTests: XCTestCase {
    func test_legacyConvenienceInit_buildsPriceCrossingOneShot() {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 75000, direction: .above)
        XCTAssertEqual(alert.recurrence, .oneShot)
        XCTAssertEqual(alert.condition,
                       .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000))
        XCTAssertTrue(alert.isActive)
        XCTAssertNil(alert.firedAt)
        XCTAssertNil(alert.lastConditionResult)
    }

    func test_directionAlias_resolvesToAlertConditionDirection() {
        // The convenience init takes PriceAlert.Direction (an alias).
        let above: PriceAlert.Direction = .above
        let below: PriceAlert.Direction = .below
        XCTAssertNotEqual(above, below)
    }

    func test_fullInit_storesAllFields() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 100)
        let alert = PriceAlert(
            id: id,
            condition: .portfolioValue(direction: .above, threshold: 50_000),
            recurrence: .cooldown(seconds: 3600),
            isActive: false,
            firedAt: date,
            lastConditionResult: true
        )
        XCTAssertEqual(alert.id, id)
        XCTAssertEqual(alert.recurrence, .cooldown(seconds: 3600))
        XCTAssertEqual(alert.firedAt, date)
        XCTAssertEqual(alert.lastConditionResult, true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -20
```
Expected: COMPILE FAILURE — `PriceAlert` initializer mismatch, no `condition` member.

- [ ] **Step 3: Refactor `PriceAlert.swift`**

Replace the entire contents of `CryptoPortfolio/Domain/Entities/PriceAlert.swift` with:

```swift
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
```

- [ ] **Step 4: Build the full project (legacy call sites may now fail)**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -40
```
Expected: At minimum the compile fails in `AlertRepositoryImpl.swift`, `EvaluateAlertsUseCase.swift`, `CreateAlertViewModel.swift`, `AlertRow.swift`, and `AppContainer.swift` because they still reference the removed top-level `coinId/targetPrice/direction` properties of `PriceAlert`. Note the errors — Tasks 3-8 fix each in turn. **DO NOT** try to fix them here; the backward-compat init is what protects the *tests*, not those call sites.

- [ ] **Step 5: Apply transitional shims so the project compiles**

The infra needs to compile before Task 3 can refactor it. Add the following **temporary** computed accessors at the bottom of `CryptoPortfolio/Domain/Entities/PriceAlert.swift`. They will be removed in Task 11.

```swift
// MARK: - Transitional accessors (removed in Task 11)
//
// These let v1.0 infrastructure (AlertRepositoryImpl, EvaluateAlertsUseCase,
// AlertRow, AppContainer.evaluateAndNotify) keep compiling while we land the
// polymorphic stack incrementally. Each one is the .priceCrossing projection;
// they trap if used against a non-priceCrossing condition.
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
```

- [ ] **Step 6: Rebuild and run the existing v1.0 alert tests**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/Alerts \
       -only-testing:CryptoPortfolioTests/AlertConditionTests \
       -only-testing:CryptoPortfolioTests/RecurrenceTests \
       -only-testing:CryptoPortfolioTests/PriceAlertTests 2>&1 | tail -30
```
Expected: PASS — pre-existing alert suite still green; the three new tests in `PriceAlertTests` pass.

- [ ] **Step 7: Commit**

```bash
git add CryptoPortfolio/Domain/Entities/PriceAlert.swift \
        CryptoPortfolioTests/Alerts/Domain/PriceAlertTests.swift
git commit -m "refactor(alerts): make PriceAlert polymorphic with backward-compat init

PriceAlert now stores AlertCondition+Recurrence+lastConditionResult; the
old (coinId,targetPrice,direction) initializer is preserved as a convenience
that synthesises .priceCrossing+.oneShot. Transitional computed accessors
keep legacy infrastructure compiling until Task 11.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Domain — `Coin` 7d/30d fields

**Files:**
- Modify: `CryptoPortfolio/Domain/Entities/Coin.swift`
- Test: `CryptoPortfolioTests/Domain/CoinTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Domain/CoinTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

final class CoinTests: XCTestCase {
    func test_init_withoutPercentFields_defaultsToNil() {
        let coin = Coin(id: "btc", symbol: "btc", name: "Bitcoin")
        XCTAssertNil(coin.priceChangePercentage7d)
        XCTAssertNil(coin.priceChangePercentage30d)
    }

    func test_init_storesPercentFields() {
        let coin = Coin(
            id: "btc", symbol: "btc", name: "Bitcoin",
            priceChangePercentage7d: -3.5,
            priceChangePercentage30d: 12.1
        )
        XCTAssertEqual(coin.priceChangePercentage7d, -3.5)
        XCTAssertEqual(coin.priceChangePercentage30d, 12.1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -10
```
Expected: COMPILE FAILURE — `priceChangePercentage7d` / `30d` not found on `Coin`.

- [ ] **Step 3: Add the fields to `Coin.swift`**

In `CryptoPortfolio/Domain/Entities/Coin.swift`, add two optional Double properties after `low24h: Double?` and parameters to the initializer. The full file becomes:

```swift
import Foundation

/// A tradable coin with its latest market snapshot. Stats fields are optional
/// because not every code path needs them (search results carry no price/stats).
struct Coin: Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let imageURL: URL?
    let currentPrice: Double
    let priceChangePercentage24h: Double
    let marketCap: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChangePercentage7d: Double?
    let priceChangePercentage30d: Double?

    init(
        id: String,
        symbol: String,
        name: String,
        imageURL: URL? = nil,
        currentPrice: Double = 0,
        priceChangePercentage24h: Double = 0,
        marketCap: Double? = nil,
        high24h: Double? = nil,
        low24h: Double? = nil,
        priceChangePercentage7d: Double? = nil,
        priceChangePercentage30d: Double? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
        self.marketCap = marketCap
        self.high24h = high24h
        self.low24h = low24h
        self.priceChangePercentage7d = priceChangePercentage7d
        self.priceChangePercentage30d = priceChangePercentage30d
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CoinTests 2>&1 | tail -10
```
Expected: PASS — 2/2.

- [ ] **Step 5: Sanity-check the rest of the alert suite still passes**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/Alerts 2>&1 | tail -20
```
Expected: PASS — pre-existing alert suite unchanged.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Domain/Entities/Coin.swift \
        CryptoPortfolioTests/Domain/CoinTests.swift
git commit -m "feat(coin): add 7d/30d percent-change fields to Coin entity

Both optional Double; default nil keeps existing call sites byte-compatible.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Data — CoinGecko DTO + mapper + endpoint update

**Files:**
- Modify: `CryptoPortfolio/Core/Data/Coin/CoinMarketDTO.swift`
- Modify: `CryptoPortfolio/Core/Data/Coin/CoinMapper.swift`
- Modify: `CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift`
- Test: `CryptoPortfolioTests/Network/CoinMarketDTOTests.swift` (existing — add tests; if absent, create)
- Test: `CryptoPortfolioTests/Network/CoinMapperTests.swift` (existing — add tests; if absent, create)
- Test: `CryptoPortfolioTests/Network/CoinGeckoEndpointsTests.swift` (existing — add tests; if absent, create)

- [ ] **Step 1: Discover existing test files**

Run:
```bash
ls CryptoPortfolioTests/Network/ 2>/dev/null
```
If `CoinMarketDTOTests.swift`, `CoinMapperTests.swift`, `CoinGeckoEndpointsTests.swift` exist, append the new test cases to them. Otherwise create them with one `final class` per file.

- [ ] **Step 2: Write the failing DTO test**

Add to (or create) `CryptoPortfolioTests/Network/CoinMarketDTOTests.swift`:

```swift
func test_decode_includes_7d_and_30d_percentChange() throws {
    let json = #"""
    {
      "id": "bitcoin", "symbol": "btc", "name": "Bitcoin",
      "current_price": 75000,
      "price_change_percentage_24h_in_currency": 1.2,
      "price_change_percentage_7d_in_currency": -3.4,
      "price_change_percentage_30d_in_currency": 12.5
    }
    """#.data(using: .utf8)!
    let dto = try JSONDecoder().decode(CoinMarketDTO.self, from: json)
    XCTAssertEqual(dto.priceChangePercentage7dInCurrency, -3.4)
    XCTAssertEqual(dto.priceChangePercentage30dInCurrency, 12.5)
}

func test_decode_missingPercentFields_yieldsNil() throws {
    let json = #"{"id":"x","symbol":"x","name":"X"}"#.data(using: .utf8)!
    let dto = try JSONDecoder().decode(CoinMarketDTO.self, from: json)
    XCTAssertNil(dto.priceChangePercentage7dInCurrency)
    XCTAssertNil(dto.priceChangePercentage30dInCurrency)
}
```

If you had to create the file, wrap it in:

```swift
import XCTest
@testable import CryptoPortfolio

final class CoinMarketDTOTests: XCTestCase {
    // <test methods here>
}
```

> **Note about `_in_currency`:** CoinGecko returns the 24h percent change as
> the bare field `price_change_percentage_24h` AND, when `price_change_percentage`
> is requested with multiple windows, additionally as
> `price_change_percentage_24h_in_currency`. For 7d/30d there is only the
> `_in_currency` form. We adopt `_in_currency` for the new fields and keep
> the existing bare `price_change_percentage_24h` field as-is to avoid
> disturbing the existing DTO contract.

- [ ] **Step 3: Write the failing mapper test**

Add to (or create) `CryptoPortfolioTests/Network/CoinMapperTests.swift`:

```swift
func test_marketMapping_wires7dAnd30dInto_Coin() {
    let dto = CoinMarketDTO(
        id: "btc", symbol: "btc", name: "Bitcoin",
        currentPrice: 75000,
        priceChangePercentage24h: 1.2,
        priceChangePercentage7dInCurrency: -3.4,
        priceChangePercentage30dInCurrency: 12.5
    )
    let coin = CoinMapper.map(dto)
    XCTAssertEqual(coin.priceChangePercentage7d, -3.4)
    XCTAssertEqual(coin.priceChangePercentage30d, 12.5)
}
```

If file creation needed, wrap with the usual `XCTestCase` boilerplate.

- [ ] **Step 4: Write the failing endpoint test**

Add to (or create) `CryptoPortfolioTests/Network/CoinGeckoEndpointsTests.swift`:

```swift
func test_marketsEndpoint_requestsAllThreePercentWindows() {
    let endpoint = CoinGeckoEndpoints.markets(ids: ["bitcoin"], vsCurrency: "usd")
    let value = endpoint.queryItems.first(where: { $0.name == "price_change_percentage" })?.value
    XCTAssertEqual(value, "24h,7d,30d")
}
```

- [ ] **Step 5: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -20
```
Expected: COMPILE FAILURE on the new DTO fields and mapper init args.

- [ ] **Step 6: Update `CoinMarketDTO.swift`**

Replace the contents of `CryptoPortfolio/Core/Data/Coin/CoinMarketDTO.swift` with:

```swift
import Foundation

/// One row from CoinGecko `/coins/markets`. Optional numeric fields tolerate
/// partial responses. Explicit CodingKeys because the shared decoder has no
/// key strategy configured.
struct CoinMarketDTO: Decodable {
    let id: String
    let symbol: String
    let name: String
    let image: String?
    let currentPrice: Double?
    let priceChangePercentage24h: Double?
    let marketCap: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChangePercentage7dInCurrency: Double?
    let priceChangePercentage30dInCurrency: Double?

    init(
        id: String,
        symbol: String,
        name: String,
        image: String? = nil,
        currentPrice: Double? = nil,
        priceChangePercentage24h: Double? = nil,
        marketCap: Double? = nil,
        high24h: Double? = nil,
        low24h: Double? = nil,
        priceChangePercentage7dInCurrency: Double? = nil,
        priceChangePercentage30dInCurrency: Double? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.image = image
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
        self.marketCap = marketCap
        self.high24h = high24h
        self.low24h = low24h
        self.priceChangePercentage7dInCurrency = priceChangePercentage7dInCurrency
        self.priceChangePercentage30dInCurrency = priceChangePercentage30dInCurrency
    }

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case marketCap = "market_cap"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChangePercentage7dInCurrency = "price_change_percentage_7d_in_currency"
        case priceChangePercentage30dInCurrency = "price_change_percentage_30d_in_currency"
    }
}
```

- [ ] **Step 7: Update `CoinMapper.swift`**

Replace `CoinMapper.map(_:CoinMarketDTO)` so the full file reads:

```swift
import Foundation

/// Maps CoinGecko DTOs to the domain `Coin` entity.
enum CoinMapper {
    static func map(_ dto: CoinMarketDTO) -> Coin {
        Coin(
            id: dto.id,
            symbol: dto.symbol,
            name: dto.name,
            imageURL: dto.image.flatMap(URL.init(string:)),
            currentPrice: dto.currentPrice ?? 0,
            priceChangePercentage24h: dto.priceChangePercentage24h ?? 0,
            marketCap: dto.marketCap,
            high24h: dto.high24h,
            low24h: dto.low24h,
            priceChangePercentage7d: dto.priceChangePercentage7dInCurrency,
            priceChangePercentage30d: dto.priceChangePercentage30dInCurrency
        )
    }

    static func map(_ dto: CoinSearchItemDTO) -> Coin {
        Coin(
            id: dto.id,
            symbol: dto.symbol,
            name: dto.name,
            imageURL: (dto.large ?? dto.thumb).flatMap(URL.init(string:)),
            currentPrice: 0,
            priceChangePercentage24h: 0
        )
    }
}
```

- [ ] **Step 8: Update `CoinGeckoEndpoints.swift`**

Edit `CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift`. The only change is the query-param value:

```swift
URLQueryItem(name: "price_change_percentage", value: "24h,7d,30d")
```

- [ ] **Step 9: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CoinMarketDTOTests \
       -only-testing:CryptoPortfolioTests/CoinMapperTests \
       -only-testing:CryptoPortfolioTests/CoinGeckoEndpointsTests 2>&1 | tail -20
```
Expected: PASS — all new tests green; pre-existing tests in the same files still green.

- [ ] **Step 10: Commit**

```bash
git add CryptoPortfolio/Core/Data/Coin/CoinMarketDTO.swift \
        CryptoPortfolio/Core/Data/Coin/CoinMapper.swift \
        CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift \
        CryptoPortfolioTests/Network
git commit -m "feat(coingecko): request and decode 7d/30d percent-change windows

markets endpoint now asks for 24h,7d,30d. DTO + mapper carry the new
_in_currency fields into Coin.priceChangePercentage7d/30d.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Data — CDAlert schema v2 (versioned model + lightweight migration)

**Files:**
- Create: `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio_v2.xcdatamodel/contents`
- Create: `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/.xccurrentversion`
- Rename: `CryptoPortfolio.xcdatamodel` directory → `CryptoPortfolio_v1.xcdatamodel`
- Test: `CryptoPortfolioTests/Persistence/CoreDataMigrationTests.swift` (new)

- [ ] **Step 1: Rename the existing model to v1**

Run:
```bash
cd CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld
mv CryptoPortfolio.xcdatamodel CryptoPortfolio_v1.xcdatamodel
cd -
```

- [ ] **Step 2: Create the `.xccurrentversion` plist pointing at v2**

Create `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/.xccurrentversion` with exactly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>_XCCurrentVersionName</key>
	<string>CryptoPortfolio_v2.xcdatamodel</string>
</dict>
</plist>
```

- [ ] **Step 3: Create the v2 model directory and contents**

Create directory `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio_v2.xcdatamodel/`. Inside it create `contents` with exactly:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="22500" systemVersion="23F79" minimumToolsVersion="Automatic" sourceLanguage="Swift" usedWithSwiftData="false" userDefinedModelVersionIdentifier="">
    <entity name="CDCachedCoin" representedClassName="CDCachedCoin" syncable="YES" codeGenerationType="class">
        <attribute name="id" optional="NO" attributeType="String"/>
        <attribute name="symbol" optional="YES" attributeType="String"/>
        <attribute name="name" optional="YES" attributeType="String"/>
        <attribute name="imageURL" optional="YES" attributeType="String"/>
        <attribute name="currentPrice" optional="NO" attributeType="Double" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="priceChangePercentage24h" optional="NO" attributeType="Double" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="updatedAt" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
        <uniquenessConstraints>
            <uniquenessConstraint>
                <constraint value="id"/>
            </uniquenessConstraint>
        </uniquenessConstraints>
    </entity>
    <entity name="CDHolding" representedClassName="CDHolding" syncable="YES" codeGenerationType="class">
        <attribute name="coinId" optional="NO" attributeType="String"/>
        <attribute name="amount" optional="NO" attributeType="Double" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="averageBuyPrice" optional="NO" attributeType="Double" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="dateAdded" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
        <uniquenessConstraints>
            <uniquenessConstraint>
                <constraint value="coinId"/>
            </uniquenessConstraint>
        </uniquenessConstraints>
    </entity>
    <entity name="CDWatchItem" representedClassName="CDWatchItem" syncable="YES" codeGenerationType="class">
        <attribute name="coinId" optional="NO" attributeType="String"/>
        <attribute name="addedAt" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
        <uniquenessConstraints>
            <uniquenessConstraint>
                <constraint value="coinId"/>
            </uniquenessConstraint>
        </uniquenessConstraints>
    </entity>
    <entity name="CDAlert" representedClassName="CDAlert" syncable="YES" codeGenerationType="class">
        <attribute name="id" optional="NO" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="coinId" optional="YES" attributeType="String"/>
        <attribute name="targetPrice" optional="NO" attributeType="Double" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="direction" optional="NO" attributeType="String" defaultValueString="above"/>
        <attribute name="isActive" optional="NO" attributeType="Boolean" defaultValueString="YES" usesScalarValueType="YES"/>
        <attribute name="firedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="conditionJSON" optional="YES" attributeType="String"/>
        <attribute name="recurrenceJSON" optional="YES" attributeType="String"/>
        <attribute name="lastConditionResult" optional="YES" attributeType="Boolean" usesScalarValueType="NO"/>
        <uniquenessConstraints>
            <uniquenessConstraint>
                <constraint value="id"/>
            </uniquenessConstraint>
        </uniquenessConstraints>
    </entity>
</model>
```

The only schema deltas vs. v1 on CDAlert are:
- `coinId` becomes `optional="YES"`.
- Three new optional attributes: `conditionJSON` (String), `recurrenceJSON` (String), `lastConditionResult` (Boolean, **no** `usesScalarValueType` — we want `NSNumber?` so we can detect "unset" distinctly from `false`).

- [ ] **Step 4: Confirm `CoreDataStack` already opts into lightweight migration**

Run:
```bash
grep -n "shouldInferMappingModelAutomatically\|shouldMigrateStoreAutomatically" CryptoPortfolio/Core/Persistence/CoreDataStack.swift
```

If both are `true`, no change needed. If not, edit `CoreDataStack.swift` so the `NSPersistentStoreDescription` it creates sets:

```swift
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
```

(Most likely they are already enabled — Phase 1 set them up. Verify before editing.)

- [ ] **Step 5: Regenerate the Xcode project**

Run:
```bash
xcodegen generate
```
Expected: No errors; both `.xcdatamodel` directories under `CryptoPortfolio.xcdatamodeld/` are picked up.

- [ ] **Step 6: Write a migration smoke test**

Create `CryptoPortfolioTests/Persistence/CoreDataMigrationTests.swift`:

```swift
import XCTest
import CoreData
@testable import CryptoPortfolio

final class CoreDataMigrationTests: XCTestCase {
    func test_freshStore_hasV2Attributes_onCDAlert() throws {
        let stack = CoreDataStack(inMemory: true)
        let entity = NSEntityDescription.entity(forEntityName: "CDAlert",
                                                in: stack.viewContext)
        XCTAssertNotNil(entity)
        let attrs = entity?.attributesByName ?? [:]
        XCTAssertTrue(attrs["conditionJSON"] != nil)
        XCTAssertTrue(attrs["recurrenceJSON"] != nil)
        XCTAssertTrue(attrs["lastConditionResult"] != nil)
        // coinId must now be optional.
        XCTAssertEqual(attrs["coinId"]?.isOptional, true)
    }
}
```

- [ ] **Step 7: Run the migration test**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CoreDataMigrationTests 2>&1 | tail -10
```
Expected: PASS — the v2 model is loaded and exposes the three new attributes.

- [ ] **Step 8: Commit**

```bash
git add CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld \
        CryptoPortfolioTests/Persistence/CoreDataMigrationTests.swift \
        CryptoPortfolio.xcodeproj project.yml 2>/dev/null || true
git add -A CryptoPortfolio CryptoPortfolioTests
git commit -m "feat(coredata): CDAlert v2 with polymorphic JSON columns

Versioned the .xcdatamodeld; v2 keeps every v1 attribute and adds
conditionJSON/recurrenceJSON/lastConditionResult on CDAlert, makes
coinId optional. Lightweight migration handles existing rows.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Data — `AlertRepositoryImpl` polymorphic mapping

**Files:**
- Modify: `CryptoPortfolio/Features/Alerts/Data/AlertRepositoryImpl.swift`
- Test: `CryptoPortfolioTests/Alerts/Data/AlertRepositoryImplTests.swift` (existing — add cases)

- [ ] **Step 1: Write failing tests for legacy decode + JSON round-trip**

Add to `CryptoPortfolioTests/Alerts/Data/AlertRepositoryImplTests.swift` (or create the file with the standard `XCTestCase` wrapper if missing). Each test starts from an empty in-memory stack via `CoreDataStack(inMemory: true)`.

```swift
func test_save_priceCrossingOneShot_roundTrip() throws {
    let stack = CoreDataStack(inMemory: true)
    let repo = AlertRepositoryImpl(stack: stack)
    let alert = PriceAlert(coinId: "bitcoin", targetPrice: 75000, direction: .above)
    try repo.save(alert)
    let loaded = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertEqual(loaded.condition,
                   .priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000))
    XCTAssertEqual(loaded.recurrence, .oneShot)
    XCTAssertNil(loaded.lastConditionResult)
}

func test_save_percentChange_cooldown_roundTrip() throws {
    let stack = CoreDataStack(inMemory: true)
    let repo = AlertRepositoryImpl(stack: stack)
    let alert = PriceAlert(
        condition: .percentChange(coinId: "ethereum", direction: .below, window: .d7, threshold: -5),
        recurrence: .cooldown(seconds: 3600)
    )
    try repo.save(alert)
    let loaded = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertEqual(loaded.condition,
                   .percentChange(coinId: "ethereum", direction: .below, window: .d7, threshold: -5))
    XCTAssertEqual(loaded.recurrence, .cooldown(seconds: 3600))
}

func test_save_portfolioValue_onCrossing_roundTrip_preservesLastResult() throws {
    let stack = CoreDataStack(inMemory: true)
    let repo = AlertRepositoryImpl(stack: stack)
    let alert = PriceAlert(
        condition: .portfolioValue(direction: .above, threshold: 100_000),
        recurrence: .onCrossing,
        lastConditionResult: true
    )
    try repo.save(alert)
    let loaded = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertEqual(loaded.condition, .portfolioValue(direction: .above, threshold: 100_000))
    XCTAssertEqual(loaded.recurrence, .onCrossing)
    XCTAssertEqual(loaded.lastConditionResult, true)
}

func test_legacyRow_withoutConditionJSON_decodesAsPriceCrossingOneShot() throws {
    // Simulate a v1.0 row by writing the legacy columns directly via Core Data
    // and leaving conditionJSON / recurrenceJSON nil.
    let stack = CoreDataStack(inMemory: true)
    let context = stack.viewContext
    let entity = CDAlert(context: context)
    let id = UUID()
    entity.id = id
    entity.coinId = "bitcoin"
    entity.targetPrice = 60000
    entity.direction = "below"
    entity.isActive = true
    entity.firedAt = nil
    entity.conditionJSON = nil
    entity.recurrenceJSON = nil
    entity.lastConditionResult = nil
    try context.save()

    let repo = AlertRepositoryImpl(stack: stack)
    let loaded = try XCTUnwrap(try repo.alert(id: id))
    XCTAssertEqual(loaded.condition,
                   .priceCrossing(coinId: "bitcoin", direction: .below, targetPrice: 60000))
    XCTAssertEqual(loaded.recurrence, .oneShot)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/AlertRepositoryImplTests 2>&1 | tail -30
```
Expected: FAILURE — `save` still writes only the legacy columns; `toDomain` ignores the JSON columns, so `.percentChange`/`.portfolioValue`/`.onCrossing` cases decode as `.priceCrossing+.oneShot`.

- [ ] **Step 3: Rewrite `AlertRepositoryImpl.swift`**

Replace the full contents of `CryptoPortfolio/Features/Alerts/Data/AlertRepositoryImpl.swift` with:

```swift
import CoreData

/// Core Data-backed `AlertRepository`. Upserts by id. Persists the polymorphic
/// `AlertCondition` and `Recurrence` as JSON in dedicated columns; falls back
/// to the legacy `(coinId, targetPrice, direction)` columns when a row was
/// written by v1.0 of the app.
final class AlertRepositoryImpl: AlertRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    private var context: NSManagedObjectContext { stack.viewContext }

    func alerts() throws -> [PriceAlert] {
        let request = NSFetchRequest<CDAlert>(entityName: "CDAlert")
        return try context.fetch(request).compactMap(Self.toDomain)
    }

    func alert(id: UUID) throws -> PriceAlert? {
        try fetchEntity(id: id).flatMap(Self.toDomain)
    }

    func save(_ alert: PriceAlert) throws {
        let entity = try fetchEntity(id: alert.id) ?? CDAlert(context: context)
        entity.id = alert.id
        entity.isActive = alert.isActive
        entity.firedAt = alert.firedAt
        entity.conditionJSON = try Self.encodeJSON(alert.condition)
        entity.recurrenceJSON = try Self.encodeJSON(alert.recurrence)
        entity.lastConditionResult = alert.lastConditionResult.map { NSNumber(value: $0) }
        // Mirror legacy columns for .priceCrossing variants so Core Data dumps
        // / future v1.x queries stay readable. Other variants leave them at
        // sentinel values that the legacy decoder would interpret as "above 0",
        // but we never fall back to those columns when conditionJSON is present.
        switch alert.condition {
        case .priceCrossing(let coinId, let direction, let targetPrice):
            entity.coinId = coinId
            entity.targetPrice = targetPrice
            entity.direction = direction.rawValue
        case .percentChange, .portfolioValue, .portfolioPnLPercent:
            entity.coinId = nil
            entity.targetPrice = 0
            entity.direction = "above"
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let entity = try fetchEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - Helpers

    private func fetchEntity(id: UUID) throws -> CDAlert? {
        let request = NSFetchRequest<CDAlert>(entityName: "CDAlert")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try jsonEncoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String?) -> T? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? jsonDecoder.decode(T.self, from: data)
    }

    private static func toDomain(_ entity: CDAlert) -> PriceAlert? {
        guard let id = entity.id else { return nil }
        let condition: AlertCondition
        if let parsed = decode(AlertCondition.self, from: entity.conditionJSON) {
            condition = parsed
        } else {
            // Legacy row: synthesise .priceCrossing from the v1 columns.
            guard let coinId = entity.coinId,
                  let rawDirection = entity.direction,
                  let direction = AlertCondition.Direction(rawValue: rawDirection)
            else { return nil }
            condition = .priceCrossing(coinId: coinId, direction: direction, targetPrice: entity.targetPrice)
        }
        let recurrence = decode(Recurrence.self, from: entity.recurrenceJSON) ?? .oneShot
        return PriceAlert(
            id: id,
            condition: condition,
            recurrence: recurrence,
            isActive: entity.isActive,
            firedAt: entity.firedAt,
            lastConditionResult: entity.lastConditionResult?.boolValue
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/AlertRepositoryImplTests 2>&1 | tail -20
```
Expected: PASS — all new tests green; pre-existing repo tests still green.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Data/AlertRepositoryImpl.swift \
        CryptoPortfolioTests/Alerts/Data/AlertRepositoryImplTests.swift
git commit -m "feat(alerts): polymorphic AlertRepositoryImpl with legacy fallback

save() JSON-encodes condition+recurrence into dedicated columns and mirrors
.priceCrossing into the legacy columns for debug visibility. toDomain()
prefers conditionJSON and falls back to the legacy (coinId, targetPrice,
direction) shape only when conditionJSON is nil — preserving every v1 row.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Domain — `CreateAlertUseCase` rewrite + `AlertError.invalidThreshold`

**Files:**
- Modify: `CryptoPortfolio/Features/Alerts/Domain/UseCases/CreateAlertUseCase.swift`
- Modify: `CryptoPortfolio/Features/Alerts/Domain/AlertError.swift` (existing) — locate first
- Test: `CryptoPortfolioTests/Alerts/Domain/CreateAlertUseCaseTests.swift` (existing — add cases)

- [ ] **Step 1: Locate `AlertError`**

Run:
```bash
grep -RnE "enum AlertError|case invalidPrice" CryptoPortfolio
```
Note the file and add `.invalidThreshold` next to `.invalidPrice`.

- [ ] **Step 2: Write failing tests**

Add to `CryptoPortfolioTests/Alerts/Domain/CreateAlertUseCaseTests.swift`:

```swift
func test_newSignature_savesPercentChange_withCooldown() throws {
    let repo = InMemoryAlertRepository()
    let useCase = CreateAlertUseCase(alertRepository: repo)
    try useCase(condition: .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5),
                recurrence: .cooldown(seconds: 3600))
    let saved = try XCTUnwrap(repo.saved.first)
    XCTAssertEqual(saved.condition, .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5))
    XCTAssertEqual(saved.recurrence, .cooldown(seconds: 3600))
    XCTAssertTrue(saved.isActive)
    XCTAssertNil(saved.firedAt)
}

func test_priceCrossing_rejectsNonPositiveTarget() {
    let repo = InMemoryAlertRepository()
    let useCase = CreateAlertUseCase(alertRepository: repo)
    XCTAssertThrowsError(try useCase(
        condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 0),
        recurrence: .oneShot
    )) { error in
        XCTAssertEqual(error as? AlertError, .invalidPrice)
    }
}

func test_portfolioValue_rejectsNonPositiveTarget() {
    let repo = InMemoryAlertRepository()
    let useCase = CreateAlertUseCase(alertRepository: repo)
    XCTAssertThrowsError(try useCase(
        condition: .portfolioValue(direction: .above, threshold: -1),
        recurrence: .oneShot
    )) { error in
        XCTAssertEqual(error as? AlertError, .invalidPrice)
    }
}

func test_percentChange_rejectsZeroThreshold() {
    let repo = InMemoryAlertRepository()
    let useCase = CreateAlertUseCase(alertRepository: repo)
    XCTAssertThrowsError(try useCase(
        condition: .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 0),
        recurrence: .oneShot
    )) { error in
        XCTAssertEqual(error as? AlertError, .invalidThreshold)
    }
}

func test_portfolioPnLPercent_rejectsZeroThreshold() {
    let repo = InMemoryAlertRepository()
    let useCase = CreateAlertUseCase(alertRepository: repo)
    XCTAssertThrowsError(try useCase(
        condition: .portfolioPnLPercent(direction: .below, threshold: 0),
        recurrence: .oneShot
    )) { error in
        XCTAssertEqual(error as? AlertError, .invalidThreshold)
    }
}

func test_legacyOverload_stillProducesPriceCrossingOneShot() throws {
    let repo = InMemoryAlertRepository()
    let useCase = CreateAlertUseCase(alertRepository: repo)
    try useCase(coinId: "btc", targetPrice: 75000, direction: .above)
    let saved = try XCTUnwrap(repo.saved.first)
    XCTAssertEqual(saved.recurrence, .oneShot)
    XCTAssertEqual(saved.condition, .priceCrossing(coinId: "btc", direction: .above, targetPrice: 75000))
}
```

(`InMemoryAlertRepository` already exists in `CryptoPortfolioTests/Support/Mocks.swift` from Phase 5; verify with `grep -n InMemoryAlertRepository CryptoPortfolioTests/Support/Mocks.swift` before assuming the type. If absent, the existing CreateAlertUseCaseTests file will show how mocks are wired — copy that style.)

- [ ] **Step 3: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CreateAlertUseCaseTests 2>&1 | tail -20
```
Expected: FAILURE — `CreateAlertUseCase` doesn't accept `condition:recurrence:`, and `AlertError.invalidThreshold` doesn't exist.

- [ ] **Step 4: Add `.invalidThreshold` to `AlertError`**

In the file located in Step 1 (most likely `CryptoPortfolio/Features/Alerts/Domain/AlertError.swift`), add the case so the enum reads:

```swift
enum AlertError: Error, Equatable {
    case invalidPrice
    case invalidThreshold
}
```

(Leave the rest of the file unchanged.)

- [ ] **Step 5: Rewrite `CreateAlertUseCase.swift`**

Replace the contents of `CryptoPortfolio/Features/Alerts/Domain/UseCases/CreateAlertUseCase.swift` with:

```swift
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
```

- [ ] **Step 6: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CreateAlertUseCaseTests 2>&1 | tail -20
```
Expected: PASS — new cases green; pre-existing legacy cases unchanged.

- [ ] **Step 7: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Domain/UseCases/CreateAlertUseCase.swift \
        CryptoPortfolio/Features/Alerts/Domain/AlertError.swift \
        CryptoPortfolioTests/Alerts/Domain/CreateAlertUseCaseTests.swift
git commit -m "feat(alerts): CreateAlertUseCase accepts AlertCondition + Recurrence

Per-variant validation (positive for price/portfolio-value, non-zero for
percent thresholds). Legacy (coinId,targetPrice,direction) overload kept
for backward compatibility with the v1.0 call sites and tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Domain — `EvaluateAlertsUseCase` polymorphic rewrite

**Files:**
- Modify: `CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift`
- Test: `CryptoPortfolioTests/Alerts/Domain/EvaluateAlertsUseCaseTests.swift` (existing — major additions)

This is the largest single task. We add many tests up front (TDD batch), then rewrite.

- [ ] **Step 1: Add a portfolio-repository mock**

Open `CryptoPortfolioTests/Support/Mocks.swift` and verify whether a `PortfolioRepository` mock exists.

```bash
grep -n "InMemoryPortfolioRepository\|class.*PortfolioRepository" CryptoPortfolioTests/Support/Mocks.swift
```

If none, append this to `CryptoPortfolioTests/Support/Mocks.swift`:

```swift
final class InMemoryPortfolioRepository: PortfolioRepository {
    var storage: [String: Holding] = [:]
    func holdings() throws -> [Holding] { Array(storage.values) }
    func holding(coinId: String) throws -> Holding? { storage[coinId] }
    func save(_ holding: Holding) throws { storage[holding.coinId] = holding }
    func remove(coinId: String) throws { storage.removeValue(forKey: coinId) }
}
```

Also verify that the existing `CoinRepository` mock in `Mocks.swift` exposes a way for tests to set custom return values for `markets(ids:currency:)`. (The v1.0 tests use one — look for `StubCoinRepository` or similar with a `marketsResult` array property and a `marketsCallCount` int.) If the existing mock doesn't expose `marketsCallCount`, add it now (one property + an `inc` in the method body) — the consolidation test in Step 2 needs it.

- [ ] **Step 2: Write failing tests for the new evaluator**

Add to `CryptoPortfolioTests/Alerts/Domain/EvaluateAlertsUseCaseTests.swift`:

```swift
// MARK: - Helpers used by tests below

private func evaluator(
    alerts: [PriceAlert] = [],
    holdings: [Holding] = [],
    coins: [Coin] = []
) -> (EvaluateAlertsUseCase, InMemoryAlertRepository, InMemoryPortfolioRepository, StubCoinRepository) {
    let alertRepo = InMemoryAlertRepository()
    for a in alerts { try? alertRepo.save(a) }
    let portfolioRepo = InMemoryPortfolioRepository()
    for h in holdings { try? portfolioRepo.save(h) }
    let coinRepo = StubCoinRepository()
    coinRepo.marketsResult = coins
    let useCase = EvaluateAlertsUseCase(
        alertRepository: alertRepo,
        coinRepository: coinRepo,
        portfolioRepository: portfolioRepo,
        currency: .usd
    )
    return (useCase, alertRepo, portfolioRepo, coinRepo)
}

private func coin(_ id: String,
                  price: Double = 0,
                  p24h: Double = 0,
                  p7d: Double? = nil,
                  p30d: Double? = nil) -> Coin {
    Coin(id: id, symbol: id, name: id.capitalized,
         currentPrice: price, priceChangePercentage24h: p24h,
         priceChangePercentage7d: p7d, priceChangePercentage30d: p30d)
}

// MARK: - .priceCrossing

func test_priceCrossing_above_fires_whenPriceMeetsTarget_oneShot() async throws {
    let alert = PriceAlert(coinId: "btc", targetPrice: 75000, direction: .above)
    let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 75000)])
    let firings = try await useCase()
    XCTAssertEqual(firings.count, 1)
    let saved = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertFalse(saved.isActive)
    XCTAssertNotNil(saved.firedAt)
}

func test_priceCrossing_above_doesNotFire_whenPriceBelowTarget() async throws {
    let alert = PriceAlert(coinId: "btc", targetPrice: 75000, direction: .above)
    let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 74999)])
    let firings = try await useCase()
    XCTAssertTrue(firings.isEmpty)
}

// MARK: - .percentChange

func test_percentChange_above_24h_fires_whenChangeMeetsThreshold() async throws {
    let alert = PriceAlert(
        condition: .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5),
        recurrence: .oneShot
    )
    let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", p24h: 6)])
    let firings = try await useCase()
    XCTAssertEqual(firings.count, 1)
}

func test_percentChange_below_7d_fires_whenChangeMeetsThreshold() async throws {
    let alert = PriceAlert(
        condition: .percentChange(coinId: "btc", direction: .below, window: .d7, threshold: -10),
        recurrence: .oneShot
    )
    let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", p7d: -12)])
    let firings = try await useCase()
    XCTAssertEqual(firings.count, 1)
}

func test_percentChange_30d_missingField_skipsWithoutStateChange() async throws {
    let alert = PriceAlert(
        condition: .percentChange(coinId: "btc", direction: .above, window: .d30, threshold: 5),
        recurrence: .oneShot
    )
    let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", p30d: nil)])
    let firings = try await useCase()
    XCTAssertTrue(firings.isEmpty)
    // Untouched — still active, never fired.
    let saved = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertTrue(saved.isActive)
    XCTAssertNil(saved.firedAt)
}

// MARK: - .portfolioValue

func test_portfolioValue_above_fires_whenTotalValueMeetsThreshold() async throws {
    let alert = PriceAlert(
        condition: .portfolioValue(direction: .above, threshold: 100_000),
        recurrence: .oneShot
    )
    let holding = Holding(coinId: "btc", amount: 2, averageBuyPrice: 30000)
    let (useCase, _, _, _) = evaluator(alerts: [alert],
                                        holdings: [holding],
                                        coins: [coin("btc", price: 60000)])
    // total = 2 * 60000 = 120000 > 100000
    let firings = try await useCase()
    XCTAssertEqual(firings.count, 1)
}

// MARK: - .portfolioPnLPercent

func test_portfolioPnLPercent_below_fires_whenPnLPercentBeatsThreshold() async throws {
    let alert = PriceAlert(
        condition: .portfolioPnLPercent(direction: .below, threshold: -10),
        recurrence: .oneShot
    )
    // Bought 1 btc @ 100; now worth 80 → -20% P/L
    let holding = Holding(coinId: "btc", amount: 1, averageBuyPrice: 100)
    let (useCase, _, _, _) = evaluator(alerts: [alert],
                                        holdings: [holding],
                                        coins: [coin("btc", price: 80)])
    let firings = try await useCase()
    XCTAssertEqual(firings.count, 1)
}

// MARK: - Recurrence: cooldown

func test_cooldown_doesNotFire_beforeIntervalElapses() async throws {
    let now = Date(timeIntervalSince1970: 1000)
    let alert = PriceAlert(
        condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
        recurrence: .cooldown(seconds: 3600),
        firedAt: Date(timeIntervalSince1970: 500) // 500s ago
    )
    let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
    let firings = try await useCase(now: now)
    XCTAssertTrue(firings.isEmpty)
}

func test_cooldown_fires_afterIntervalElapses() async throws {
    let now = Date(timeIntervalSince1970: 5000)
    let alert = PriceAlert(
        condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
        recurrence: .cooldown(seconds: 3600),
        firedAt: Date(timeIntervalSince1970: 500) // 4500s ago > 3600
    )
    let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
    let firings = try await useCase(now: now)
    XCTAssertEqual(firings.count, 1)
    let saved = try XCTUnwrap(try repo.alert(id: alert.id))
    // Cooldown alerts stay active across firings.
    XCTAssertTrue(saved.isActive)
    XCTAssertEqual(saved.firedAt, now)
}

// MARK: - Recurrence: onCrossing

func test_onCrossing_fires_onFalseToTrueTransition() async throws {
    let alert = PriceAlert(
        condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
        recurrence: .onCrossing,
        lastConditionResult: false
    )
    let (useCase, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
    let firings = try await useCase()
    XCTAssertEqual(firings.count, 1)
    let saved = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertEqual(saved.lastConditionResult, true)
    XCTAssertTrue(saved.isActive) // onCrossing stays armed
}

func test_onCrossing_doesNotFire_whenAlreadyTrue() async throws {
    let alert = PriceAlert(
        condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
        recurrence: .onCrossing,
        lastConditionResult: true
    )
    let (useCase, _, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 110)])
    let firings = try await useCase()
    XCTAssertTrue(firings.isEmpty)
}

func test_onCrossing_firesAgain_afterTransientFalse() async throws {
    // Two consecutive evaluations: price first dips below, then crosses back.
    let alert = PriceAlert(
        condition: .priceCrossing(coinId: "btc", direction: .above, targetPrice: 100),
        recurrence: .onCrossing,
        lastConditionResult: true
    )
    // First pass: price drops.
    let (useCase1, repo, _, _) = evaluator(alerts: [alert], coins: [coin("btc", price: 90)])
    _ = try await useCase1()
    let afterDip = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertEqual(afterDip.lastConditionResult, false)
    XCTAssertTrue(afterDip.isActive)

    // Second pass against the same repo: price recovers.
    let coinRepo = StubCoinRepository()
    coinRepo.marketsResult = [coin("btc", price: 120)]
    let useCase2 = EvaluateAlertsUseCase(
        alertRepository: repo,
        coinRepository: coinRepo,
        portfolioRepository: InMemoryPortfolioRepository(),
        currency: .usd
    )
    let firings = try await useCase2()
    XCTAssertEqual(firings.count, 1)
    let afterRecovery = try XCTUnwrap(try repo.alert(id: alert.id))
    XCTAssertEqual(afterRecovery.lastConditionResult, true)
}

// MARK: - Consolidation

func test_singleMarketsCall_perPass_regardlessOfConditionMix() async throws {
    let a1 = PriceAlert(coinId: "btc", targetPrice: 1, direction: .above)
    let a2 = PriceAlert(
        condition: .percentChange(coinId: "eth", direction: .above, window: .h24, threshold: 1),
        recurrence: .oneShot
    )
    let a3 = PriceAlert(
        condition: .portfolioValue(direction: .above, threshold: 1),
        recurrence: .oneShot
    )
    let holding = Holding(coinId: "doge", amount: 1, averageBuyPrice: 0.1)
    let (useCase, _, _, coinRepo) = evaluator(
        alerts: [a1, a2, a3],
        holdings: [holding],
        coins: [coin("btc", price: 2), coin("eth", p24h: 2), coin("doge", price: 0.2)]
    )
    _ = try await useCase()
    XCTAssertEqual(coinRepo.marketsCallCount, 1)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/EvaluateAlertsUseCaseTests 2>&1 | tail -40
```
Expected: COMPILE FAILURE (initializer has no `portfolioRepository:` arg) or test failures across the matrix.

- [ ] **Step 4: Rewrite `EvaluateAlertsUseCase.swift`**

Replace the contents of `CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift` with:

```swift
import Foundation

/// Polymorphic alert evaluation. One consolidated markets fetch per pass.
/// Persists firing state (`firedAt`, `isActive`, `lastConditionResult`) and
/// returns one `AlertFiring` per alert that should notify the user this pass.
struct EvaluateAlertsUseCase {
    let alertRepository: AlertRepository
    let coinRepository: CoinRepository
    let portfolioRepository: PortfolioRepository
    let currency: Currency

    func callAsFunction(now: Date = Date()) async throws -> [AlertFiring] {
        let active = try alertRepository.alerts().filter { $0.isActive }
        guard !active.isEmpty else { return [] }

        // 1) Gather data requirements.
        var coinIds: Set<String> = []
        var needsPortfolio = false
        for alert in active {
            if let ids = alert.condition.requiredCoinIds {
                coinIds.formUnion(ids)
            } else {
                needsPortfolio = true
            }
        }
        var holdings: [Holding] = []
        if needsPortfolio {
            holdings = try portfolioRepository.holdings()
            coinIds.formUnion(holdings.map(\.coinId))
        }

        // 2) Single consolidated markets call.
        let coins: [Coin]
        if coinIds.isEmpty {
            coins = []
        } else {
            coins = try await coinRepository.markets(ids: Array(coinIds), currency: currency)
        }
        let coinsById = Dictionary(coins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // 3) Portfolio summary (only when needed).
        let summary: PortfolioSummary? = needsPortfolio
            ? Self.buildSummary(holdings: holdings, coinsById: coinsById)
            : nil

        // 4) Per-alert eval + fire-decision + persisted state update.
        var firings: [AlertFiring] = []
        for alert in active {
            guard let conditionTrue = evaluate(alert.condition,
                                               coinsById: coinsById,
                                               summary: summary) else {
                // Missing data — skip without state change.
                continue
            }
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

    // MARK: - Per-variant evaluation

    /// Returns `nil` when required data is missing (e.g., the coin was not in
    /// the markets response, or a percent-window field is nil). Returning nil
    /// signals "no state change this pass" to the caller.
    private func evaluate(_ condition: AlertCondition,
                          coinsById: [String: Coin],
                          summary: PortfolioSummary?) -> Bool? {
        switch condition {
        case .priceCrossing(let coinId, let direction, let target):
            guard let coin = coinsById[coinId] else { return nil }
            switch direction {
            case .above: return coin.currentPrice >= target
            case .below: return coin.currentPrice <= target
            }
        case .percentChange(let coinId, let direction, let window, let threshold):
            guard let coin = coinsById[coinId] else { return nil }
            let value: Double?
            switch window {
            case .h24: value = coin.priceChangePercentage24h
            case .d7:  value = coin.priceChangePercentage7d
            case .d30: value = coin.priceChangePercentage30d
            }
            guard let v = value else { return nil }
            switch direction {
            case .above: return v >= threshold
            case .below: return v <= threshold
            }
        case .portfolioValue(let direction, let target):
            guard let summary else { return nil }
            switch direction {
            case .above: return summary.totalValue >= target
            case .below: return summary.totalValue <= target
            }
        case .portfolioPnLPercent(let direction, let target):
            guard let summary else { return nil }
            switch direction {
            case .above: return summary.percentPnL >= target
            case .below: return summary.percentPnL <= target
            }
        }
    }

    // MARK: - Recurrence state machine

    private func shouldFire(_ alert: PriceAlert,
                            conditionTrue: Bool,
                            now: Date) -> Bool {
        guard conditionTrue else { return false }
        switch alert.recurrence {
        case .oneShot:
            return alert.firedAt == nil
        case .cooldown(let seconds):
            guard let last = alert.firedAt else { return true }
            return now.timeIntervalSince(last) >= seconds
        case .onCrossing:
            return alert.lastConditionResult != true
        }
    }

    // MARK: - Summary

    /// Mirrors `GetPortfolioSummaryUseCase` — kept private to the evaluator so
    /// we don't introduce a cross-use-case dependency just to share math.
    private static func buildSummary(holdings: [Holding],
                                     coinsById: [String: Coin]) -> PortfolioSummary {
        var items: [HoldingValuation] = []
        var totalValue = 0.0
        var totalCost = 0.0
        for holding in holdings {
            let coin = coinsById[holding.coinId]
            let price = coin?.currentPrice ?? 0
            let value = holding.amount * price
            let cost = holding.amount * holding.averageBuyPrice
            items.append(HoldingValuation(holding: holding, coin: coin,
                                          currentValue: value, cost: cost))
            totalValue += value
            totalCost += cost
        }
        let pnl = totalValue - totalCost
        let pct = totalCost > 0 ? (pnl / totalCost) * 100 : 0
        return PortfolioSummary(
            totalValue: totalValue, totalCost: totalCost,
            absolutePnL: pnl, percentPnL: pct, items: items
        )
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/EvaluateAlertsUseCaseTests 2>&1 | tail -40
```
Expected: PASS — both pre-existing v1 cases and all new polymorphic cases green.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift \
        CryptoPortfolioTests/Alerts/Domain/EvaluateAlertsUseCaseTests.swift \
        CryptoPortfolioTests/Support/Mocks.swift
git commit -m "feat(alerts): polymorphic EvaluateAlertsUseCase

Adds portfolioRepository dependency, consolidates markets fetch to a
single call per pass, evaluates each AlertCondition variant, and enforces
the recurrence state machine (oneShot / cooldown / onCrossing). Missing
data skips alerts without touching their persisted state.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Core — `AlertNotificationFormatter` + `AppContainer` wiring

**Files:**
- Create: `CryptoPortfolio/Core/Notifications/AlertNotificationFormatter.swift`
- Modify: `CryptoPortfolio/Core/DI/AppContainer.swift`
- Test: `CryptoPortfolioTests/Notifications/AlertNotificationFormatterTests.swift` (new)

- [ ] **Step 1: Write failing formatter tests**

Create `CryptoPortfolioTests/Notifications/AlertNotificationFormatterTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

final class AlertNotificationFormatterTests: XCTestCase {
    private func firing(_ condition: AlertCondition, coinName: String? = nil) -> AlertFiring {
        AlertFiring(
            alert: PriceAlert(condition: condition, recurrence: .oneShot),
            firedAt: Date()
        )
    }

    func test_priceCrossing_body_includesCoinAndPrice() {
        let body = AlertNotificationFormatter.body(
            for: firing(.priceCrossing(coinId: "bitcoin", direction: .above, targetPrice: 75000)),
            coinName: "Bitcoin",
            currency: .usd
        )
        XCTAssertTrue(body.contains("Bitcoin"))
        XCTAssertTrue(body.contains("75"))
    }

    func test_percentChange_body_includesPercentAndWindow() {
        let body = AlertNotificationFormatter.body(
            for: firing(.percentChange(coinId: "eth", direction: .below, window: .d7, threshold: -5)),
            coinName: "Ethereum",
            currency: .usd
        )
        XCTAssertTrue(body.contains("Ethereum"))
        XCTAssertTrue(body.contains("5"))
        XCTAssertTrue(body.contains("7"))  // window mentioned
    }

    func test_portfolioValue_body_mentionsPortfolioAndAmount() {
        let body = AlertNotificationFormatter.body(
            for: firing(.portfolioValue(direction: .above, threshold: 100_000)),
            coinName: nil,
            currency: .usd
        )
        XCTAssertTrue(body.localizedCaseInsensitiveContains("portfolio"))
        XCTAssertTrue(body.contains("100"))
    }

    func test_portfolioPnLPercent_body_mentionsPnL() {
        let body = AlertNotificationFormatter.body(
            for: firing(.portfolioPnLPercent(direction: .below, threshold: -10)),
            coinName: nil,
            currency: .usd
        )
        XCTAssertTrue(body.contains("10"))
        XCTAssertTrue(body.localizedCaseInsensitiveContains("p/l")
                      || body.localizedCaseInsensitiveContains("pnl")
                      || body.localizedCaseInsensitiveContains("kar"))
    }

    func test_titleIsConstant() {
        let firing = firing(.priceCrossing(coinId: "btc", direction: .above, targetPrice: 1))
        XCTAssertEqual(AlertNotificationFormatter.title(for: firing),
                       String(localized: "alerts.notification.title", defaultValue: "Price alert"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -10
```
Expected: COMPILE FAILURE — `AlertNotificationFormatter` not found.

- [ ] **Step 3: Create the formatter**

Create `CryptoPortfolio/Core/Notifications/AlertNotificationFormatter.swift`:

```swift
import Foundation

/// Single source of truth for the title/body strings shown to the user when
/// an alert fires. Used by both `AppContainer.evaluateAndNotify` (foreground +
/// BGTask path) and any in-app surfaces that want to echo the same wording.
enum AlertNotificationFormatter {

    static func title(for firing: AlertFiring) -> String {
        String(localized: "alerts.notification.title", defaultValue: "Price alert")
    }

    static func body(for firing: AlertFiring,
                     coinName: String?,
                     currency: Currency) -> String {
        switch firing.alert.condition {
        case .priceCrossing(let coinId, _, let targetPrice):
            let name = coinName ?? coinId.capitalized
            let price = CurrencyFormatter.format(targetPrice, currency: currency)
            return String(
                format: String(localized: "alerts.notification.body.priceCrossing",
                               defaultValue: "%@ crossed %@"),
                name, price
            )

        case .percentChange(let coinId, _, let window, let threshold):
            let name = coinName ?? coinId.capitalized
            let percent = Self.formatPercent(threshold)
            let windowLabel = Self.windowLabel(window)
            return String(
                format: String(localized: "alerts.notification.body.percentChange",
                               defaultValue: "%@ moved %@ in %@"),
                name, percent, windowLabel
            )

        case .portfolioValue(_, let threshold):
            let amount = CurrencyFormatter.format(threshold, currency: currency)
            return String(
                format: String(localized: "alerts.notification.body.portfolioValue",
                               defaultValue: "Portfolio total reached %@"),
                amount
            )

        case .portfolioPnLPercent(_, let threshold):
            let percent = Self.formatPercent(threshold)
            return String(
                format: String(localized: "alerts.notification.body.portfolioPnLPercent",
                               defaultValue: "Portfolio P/L is now %@"),
                percent
            )
        }
    }

    private static func formatPercent(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        let n = nf.string(from: NSNumber(value: value)) ?? String(value)
        return "\(n)%"
    }

    private static func windowLabel(_ window: AlertCondition.PercentWindow) -> String {
        switch window {
        case .h24: return String(localized: "alerts.window.h24", defaultValue: "24h")
        case .d7:  return String(localized: "alerts.window.d7",  defaultValue: "7d")
        case .d30: return String(localized: "alerts.window.d30", defaultValue: "30d")
        }
    }
}
```

- [ ] **Step 4: Wire `portfolioRepository` into the evaluator factory + use the formatter**

In `CryptoPortfolio/Core/DI/AppContainer.swift`, replace `makeEvaluateAlertsUseCase` and `evaluateAndNotify` with:

```swift
func makeEvaluateAlertsUseCase(currency: Currency = .default) -> EvaluateAlertsUseCase {
    EvaluateAlertsUseCase(
        alertRepository: alertRepository,
        coinRepository: coinRepository,
        portfolioRepository: portfolioRepository,
        currency: currency
    )
}

@MainActor
@discardableResult
func evaluateAndNotify(currency: Currency = .default) async -> Int {
    do {
        let firings = try await makeEvaluateAlertsUseCase(currency: currency)(now: Date())
        for firing in firings {
            let coinName = Self.resolveCoinName(for: firing.alert.condition)
            await notifications.fire(
                title: AlertNotificationFormatter.title(for: firing),
                body: AlertNotificationFormatter.body(for: firing,
                                                     coinName: coinName,
                                                     currency: currency),
                identifier: firing.alert.id.uuidString
            )
        }
        return firings.count
    } catch {
        return 0
    }
}

/// Resolves a presentable coin name from the condition. The evaluator already
/// fetched the market data; we recover the name by re-asking the cached
/// markets path. If the lookup fails, we hand `nil` to the formatter and it
/// falls back to a capitalised coin id.
private static func resolveCoinName(for condition: AlertCondition) -> String? {
    // The condition carries the coin id; nothing else here. The formatter
    // capitalises the id as a graceful fallback, which is enough for v1.1.
    // (We deliberately don't add a name cache yet — YAGNI.)
    nil
}
```

- [ ] **Step 5: Run formatter and DI tests**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/AlertNotificationFormatterTests \
       -only-testing:CryptoPortfolioTests/DI 2>&1 | tail -20
```
Expected: PASS — formatter tests green; any DI smoke tests still green.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Core/Notifications/AlertNotificationFormatter.swift \
        CryptoPortfolio/Core/DI/AppContainer.swift \
        CryptoPortfolioTests/Notifications/AlertNotificationFormatterTests.swift
git commit -m "feat(alerts): AlertNotificationFormatter + portfolio wiring in DI

Single source of truth for notification title/body per condition variant.
AppContainer.evaluateAndNotify routes every firing through it; the
evaluator factory now injects PortfolioRepository.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Presentation — `RecurrencePickerView` (shared)

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/RecurrencePickerView.swift`
- Test: `CryptoPortfolioTests/Alerts/Presentation/RecurrencePickerViewTests.swift` (new — snapshot of state transitions, not pixel snapshots)

- [ ] **Step 1: Write failing tests for the picker's state model**

Create `CryptoPortfolioTests/Alerts/Presentation/RecurrencePickerViewTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

final class RecurrencePickerStateTests: XCTestCase {
    func test_default_isOneShot() {
        XCTAssertEqual(RecurrencePickerState().recurrence, .oneShot)
    }

    func test_selectingCooldown_setsDefault1Hour() {
        var s = RecurrencePickerState()
        s.kind = .cooldown
        XCTAssertEqual(s.recurrence, .cooldown(seconds: 3600))
    }

    func test_pickingCooldown6h() {
        var s = RecurrencePickerState()
        s.kind = .cooldown
        s.cooldownSeconds = 21600
        XCTAssertEqual(s.recurrence, .cooldown(seconds: 21600))
    }

    func test_pickingOnCrossing() {
        var s = RecurrencePickerState()
        s.kind = .onCrossing
        XCTAssertEqual(s.recurrence, .onCrossing)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -10
```
Expected: COMPILE FAILURE — `RecurrencePickerState` not found.

- [ ] **Step 3: Create the picker view + state**

Create `CryptoPortfolio/Features/Alerts/Presentation/RecurrencePickerView.swift`:

```swift
import SwiftUI

/// Light value-type state model shared by every Create*AlertViewModel.
/// Forms own one of these and read `recurrence` when saving.
struct RecurrencePickerState: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case oneShot, cooldown, onCrossing
        var id: String { rawValue }
    }
    var kind: Kind = .oneShot
    /// Only consulted when `kind == .cooldown`. Default 1 hour.
    var cooldownSeconds: TimeInterval = 3600

    /// The `Recurrence` value to persist.
    var recurrence: Recurrence {
        switch kind {
        case .oneShot:    return .oneShot
        case .cooldown:   return .cooldown(seconds: cooldownSeconds)
        case .onCrossing: return .onCrossing
        }
    }
}

/// Inline Form section. Place inside a parent `Form { ... }`.
struct RecurrencePickerView: View {
    @Binding var state: RecurrencePickerState

    private static let cooldownPresets: [(label: LocalizedStringKey, seconds: TimeInterval)] = [
        ("alerts.cooldown.1h", 3600),
        ("alerts.cooldown.6h", 21600),
        ("alerts.cooldown.24h", 86400)
    ]

    var body: some View {
        Section {
            Picker("alerts.form.recurrence", selection: $state.kind) {
                Text("alerts.recurrence.oneShot").tag(RecurrencePickerState.Kind.oneShot)
                Text("alerts.recurrence.cooldown").tag(RecurrencePickerState.Kind.cooldown)
                Text("alerts.recurrence.onCrossing").tag(RecurrencePickerState.Kind.onCrossing)
            }
            if state.kind == .cooldown {
                Picker("alerts.cooldown.interval", selection: $state.cooldownSeconds) {
                    ForEach(Self.cooldownPresets, id: \.seconds) { preset in
                        Text(preset.label).tag(preset.seconds)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/RecurrencePickerStateTests 2>&1 | tail -10
```
Expected: PASS — 4/4.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/RecurrencePickerView.swift \
        CryptoPortfolioTests/Alerts/Presentation/RecurrencePickerViewTests.swift
git commit -m "feat(alerts): RecurrencePickerView + RecurrencePickerState

Reusable inline Form section: One shot / Cooldown (1h/6h/24h presets) /
On crossing. State exposes the resolved Recurrence to the host VM.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Presentation — `PriceAlertFormView` + VM (replaces `AlertConditionView`)

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/CreatePriceAlertViewModel.swift`
- Create: `CryptoPortfolio/Features/Alerts/Presentation/PriceAlertFormView.swift`
- Delete: `CryptoPortfolio/Features/Alerts/Presentation/AlertConditionView.swift`
- Modify: `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift` (reroute)
- Modify: `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift` (strip the form logic)
- Modify: `CryptoPortfolio/Domain/Entities/PriceAlert.swift` (remove transitional accessors)
- Test: `CryptoPortfolioTests/Alerts/Presentation/CreatePriceAlertViewModelTests.swift` (new)

- [ ] **Step 1: Write the failing VM tests**

Create `CryptoPortfolioTests/Alerts/Presentation/CreatePriceAlertViewModelTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreatePriceAlertViewModelTests: XCTestCase {
    private func makeVM() -> (CreatePriceAlertViewModel, InMemoryAlertRepository) {
        let repo = InMemoryAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        let vm = CreatePriceAlertViewModel(coin: Coin(id: "btc", symbol: "btc", name: "Bitcoin"),
                                            createAlert: useCase)
        return (vm, repo)
    }

    func test_save_happyPath_persistsPriceCrossing() async {
        let (vm, repo) = makeVM()
        vm.targetPriceText = "75000"
        vm.direction = .above
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .priceCrossing(coinId: "btc", direction: .above, targetPrice: 75000))
    }

    func test_save_commaDecimal_normalisedToDot() async {
        let (vm, repo) = makeVM()
        vm.targetPriceText = "0,5"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        if case .priceCrossing(_, _, let target) = try? repo.alerts().first?.condition {
            XCTAssertEqual(target, 0.5, accuracy: 0.0001)
        } else {
            XCTFail("expected priceCrossing")
        }
    }

    func test_save_nonNumericInput_setsLocalizedError_returnsFalse() async {
        let (vm, _) = makeVM()
        vm.targetPriceText = "abc"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_zeroTarget_setsInvalidPriceError() async {
        let (vm, _) = makeVM()
        vm.targetPriceText = "0"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_appliesCooldownRecurrence() async {
        let (vm, repo) = makeVM()
        vm.targetPriceText = "100"
        vm.recurrence.kind = .cooldown
        vm.recurrence.cooldownSeconds = 21600
        _ = await vm.save()
        XCTAssertEqual(try? repo.alerts().first?.recurrence, .cooldown(seconds: 21600))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -10
```
Expected: COMPILE FAILURE — `CreatePriceAlertViewModel` not found.

- [ ] **Step 3: Create the VM**

Create `CryptoPortfolio/Features/Alerts/Presentation/CreatePriceAlertViewModel.swift`:

```swift
import Foundation

@MainActor
final class CreatePriceAlertViewModel: ObservableObject {
    let coin: Coin
    @Published var direction: AlertCondition.Direction = .above
    @Published var targetPriceText: String = ""
    @Published var recurrence: RecurrencePickerState = RecurrencePickerState()
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let createAlert: CreateAlertUseCase

    init(coin: Coin, createAlert: CreateAlertUseCase) {
        self.coin = coin
        self.createAlert = createAlert
    }

    /// Returns true iff the alert was saved successfully.
    func save() async -> Bool {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let normalized = targetPriceText.replacingOccurrences(of: ",", with: ".")
        guard let price = Double(normalized) else {
            saveError = String(localized: "createAlert.error.priceNotNumber",
                               defaultValue: "Target price is not a number.")
            return false
        }
        do {
            try createAlert(
                condition: .priceCrossing(coinId: coin.id, direction: direction, targetPrice: price),
                recurrence: recurrence.recurrence
            )
            return true
        } catch AlertError.invalidPrice {
            saveError = String(localized: "createAlert.error.priceNotPositive",
                               defaultValue: "Target price must be greater than zero.")
            return false
        } catch {
            saveError = String(localized: "createAlert.error.saveFailed",
                               defaultValue: "Could not save alert.")
            return false
        }
    }

    func clearSaveError() { saveError = nil }
}
```

- [ ] **Step 4: Create `PriceAlertFormView.swift`**

Create `CryptoPortfolio/Features/Alerts/Presentation/PriceAlertFormView.swift`:

```swift
import SwiftUI

struct PriceAlertFormView: View {
    @StateObject private var viewModel: CreatePriceAlertViewModel
    let onSave: (Bool) -> Void

    init(coin: Coin, container: AppContainer, onSave: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreatePriceAlertViewModel(
            coin: coin,
            createAlert: container.makeCreateAlertUseCase()
        ))
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker("alerts.form.direction", selection: $viewModel.direction) {
                    Text("alerts.direction.above").tag(AlertCondition.Direction.above)
                    Text("alerts.direction.below").tag(AlertCondition.Direction.below)
                }
                .pickerStyle(.segmented)

                LabeledContent("alerts.create.targetPrice") {
                    TextField("0.00", text: $viewModel.targetPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(viewModel.coin.name)
            } footer: {
                if let error = viewModel.saveError {
                    Text(error).foregroundStyle(Theme.negative)
                }
            }

            RecurrencePickerView(state: $viewModel.recurrence)
        }
        .navigationTitle("alerts.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("alerts.create.save") {
                    Task {
                        let saved = await viewModel.save()
                        if saved { onSave(true) }
                    }
                }
                .disabled(viewModel.isSaving || viewModel.targetPriceText.isEmpty)
            }
        }
        .onAppear { viewModel.clearSaveError() }
    }
}
```

- [ ] **Step 5: Delete the obsolete `AlertConditionView.swift`**

Run:
```bash
rm CryptoPortfolio/Features/Alerts/Presentation/AlertConditionView.swift
```

- [ ] **Step 6: Strip `CreateAlertViewModel` down to the search step**

Replace `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift` with:

```swift
import Foundation

/// Backs the type-chooser/search step of the Create-Alert flow. Each form
/// downstream owns its own VM (CreatePriceAlertViewModel, CreatePercentAlertViewModel,
/// CreatePortfolioAlertViewModel).
@MainActor
final class CreateAlertViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty

    private let searchCoins: SearchCoinsUseCase

    init(searchCoins: SearchCoinsUseCase) {
        self.searchCoins = searchCoins
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { results = .empty; return }
        results = .loading
        do {
            let coins = try await searchCoins(trimmed)
            results = coins.isEmpty ? .empty : .loaded(coins)
        } catch {
            results = .error(error.userFacingMessage)
        }
    }
}
```

- [ ] **Step 7: Reroute `CreateAlertView.swift` (price flow only — chooser added in Task 14)**

Replace the body of `CreateAlertView.swift` so the search list now pushes to `PriceAlertFormView`. The chooser will be wired in Task 14. For now this keeps the previous behavior while removing the dependency on the deleted `AlertConditionView`.

```swift
import SwiftUI

struct CreateAlertView: View {
    @StateObject private var viewModel: CreateAlertViewModel
    private let container: AppContainer
    private let initialCoin: Coin?
    let onDone: (_ didCreate: Bool) -> Void

    @State private var directRoute: Coin?

    init(container: AppContainer, initialCoin: Coin? = nil, onDone: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreateAlertViewModel(
            searchCoins: container.makeSearchCoinsUseCase()
        ))
        self.container = container
        self.initialCoin = initialCoin
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("alerts.create.searchTitle")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("alerts.create.search.prompt"))
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone(false) }
                    }
                }
                .background(
                    NavigationLink(
                        isActive: Binding(
                            get: { directRoute != nil },
                            set: { if !$0 { directRoute = nil } }
                        )
                    ) {
                        if let coin = directRoute {
                            PriceAlertFormView(coin: coin, container: container) { saved in onDone(saved) }
                        }
                    } label: { EmptyView() }
                    .hidden()
                )
                .task {
                    if let coin = initialCoin, directRoute == nil {
                        directRoute = coin
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.results {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "magnifyingglass",
                titleKey: "alerts.create.empty.title",
                messageKey: "alerts.create.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }
        case .loaded(let coins):
            List(coins) { coin in
                NavigationLink {
                    PriceAlertFormView(coin: coin, container: container) { saved in onDone(saved) }
                } label: {
                    coinRow(coin)
                }
            }
            .listStyle(.plain)
        }
    }

    private func coinRow(_ coin: Coin) -> some View {
        HStack(spacing: 12) {
            if let url = coin.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    default: Circle().fill(.secondary.opacity(0.2))
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle().fill(.secondary.opacity(0.2)).frame(width: 32, height: 32)
            }
            VStack(alignment: .leading) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 8: Remove the transitional accessors from `PriceAlert.swift`**

In `CryptoPortfolio/Domain/Entities/PriceAlert.swift`, delete the `// MARK: - Transitional accessors (removed in Task 11)` block introduced in Task 2 Step 5. After deletion, the file should contain only the new struct + the backward-compat extension defined in Task 2 Step 3.

- [ ] **Step 9: Rebuild and run the alert test suite end-to-end**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/Alerts 2>&1 | tail -30
```
Expected: PASS — every alert test including the new VM tests is green.

- [ ] **Step 10: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/PriceAlertFormView.swift \
        CryptoPortfolio/Features/Alerts/Presentation/CreatePriceAlertViewModel.swift \
        CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift \
        CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift \
        CryptoPortfolio/Domain/Entities/PriceAlert.swift \
        CryptoPortfolioTests/Alerts/Presentation/CreatePriceAlertViewModelTests.swift
git rm CryptoPortfolio/Features/Alerts/Presentation/AlertConditionView.swift
git commit -m "feat(alerts): PriceAlertFormView + CreatePriceAlertViewModel

Replaces AlertConditionView with a form-specific VM that owns its own
RecurrencePickerState. CreateAlertViewModel slims down to the search
step. Transitional PriceAlert accessors removed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: Presentation — Percent change form

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/CreatePercentAlertViewModel.swift`
- Create: `CryptoPortfolio/Features/Alerts/Presentation/PercentAlertFormView.swift`
- Test: `CryptoPortfolioTests/Alerts/Presentation/CreatePercentAlertViewModelTests.swift` (new)

- [ ] **Step 1: Write failing VM tests**

Create `CryptoPortfolioTests/Alerts/Presentation/CreatePercentAlertViewModelTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreatePercentAlertViewModelTests: XCTestCase {
    private func makeVM() -> (CreatePercentAlertViewModel, InMemoryAlertRepository) {
        let repo = InMemoryAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        let vm = CreatePercentAlertViewModel(coin: Coin(id: "btc", symbol: "btc", name: "Bitcoin"),
                                              createAlert: useCase)
        return (vm, repo)
    }

    func test_save_happyPath_24h_above() async {
        let (vm, repo) = makeVM()
        vm.window = .h24
        vm.direction = .above
        vm.thresholdText = "5"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5))
    }

    func test_save_negativeThreshold_7d_below() async {
        let (vm, repo) = makeVM()
        vm.window = .d7
        vm.direction = .below
        vm.thresholdText = "-5"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .percentChange(coinId: "btc", direction: .below, window: .d7, threshold: -5))
    }

    func test_save_zeroThreshold_setsInvalidThresholdError() async {
        let (vm, _) = makeVM()
        vm.thresholdText = "0"
        XCTAssertFalse(await vm.save())
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_nonNumeric_setsLocalizedError() async {
        let (vm, _) = makeVM()
        vm.thresholdText = "abc"
        XCTAssertFalse(await vm.save())
        XCTAssertNotNil(vm.saveError)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -10
```
Expected: COMPILE FAILURE — `CreatePercentAlertViewModel` not found.

- [ ] **Step 3: Create the VM**

Create `CryptoPortfolio/Features/Alerts/Presentation/CreatePercentAlertViewModel.swift`:

```swift
import Foundation

@MainActor
final class CreatePercentAlertViewModel: ObservableObject {
    let coin: Coin
    @Published var window: AlertCondition.PercentWindow = .h24
    @Published var direction: AlertCondition.Direction = .above
    @Published var thresholdText: String = ""
    @Published var recurrence: RecurrencePickerState = RecurrencePickerState()
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let createAlert: CreateAlertUseCase

    init(coin: Coin, createAlert: CreateAlertUseCase) {
        self.coin = coin
        self.createAlert = createAlert
    }

    func save() async -> Bool {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let normalized = thresholdText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            saveError = String(localized: "createAlert.error.thresholdNotNumber",
                               defaultValue: "Threshold is not a number.")
            return false
        }
        do {
            try createAlert(
                condition: .percentChange(coinId: coin.id, direction: direction,
                                          window: window, threshold: value),
                recurrence: recurrence.recurrence
            )
            return true
        } catch AlertError.invalidThreshold {
            saveError = String(localized: "createAlert.error.thresholdZero",
                               defaultValue: "Threshold cannot be zero.")
            return false
        } catch {
            saveError = String(localized: "createAlert.error.saveFailed",
                               defaultValue: "Could not save alert.")
            return false
        }
    }

    func clearSaveError() { saveError = nil }
}
```

- [ ] **Step 4: Create `PercentAlertFormView.swift`**

Create `CryptoPortfolio/Features/Alerts/Presentation/PercentAlertFormView.swift`:

```swift
import SwiftUI

struct PercentAlertFormView: View {
    @StateObject private var viewModel: CreatePercentAlertViewModel
    let onSave: (Bool) -> Void

    init(coin: Coin, container: AppContainer, onSave: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreatePercentAlertViewModel(
            coin: coin,
            createAlert: container.makeCreateAlertUseCase()
        ))
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker("alerts.form.window", selection: $viewModel.window) {
                    Text("alerts.window.h24").tag(AlertCondition.PercentWindow.h24)
                    Text("alerts.window.d7").tag(AlertCondition.PercentWindow.d7)
                    Text("alerts.window.d30").tag(AlertCondition.PercentWindow.d30)
                }
                .pickerStyle(.segmented)

                Picker("alerts.form.direction", selection: $viewModel.direction) {
                    Text("alerts.direction.above").tag(AlertCondition.Direction.above)
                    Text("alerts.direction.below").tag(AlertCondition.Direction.below)
                }
                .pickerStyle(.segmented)

                LabeledContent("alerts.form.threshold") {
                    TextField("0.0", text: $viewModel.thresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(viewModel.coin.name)
            } footer: {
                if let error = viewModel.saveError {
                    Text(error).foregroundStyle(Theme.negative)
                }
            }

            RecurrencePickerView(state: $viewModel.recurrence)
        }
        .navigationTitle("alerts.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("alerts.create.save") {
                    Task {
                        let saved = await viewModel.save()
                        if saved { onSave(true) }
                    }
                }
                .disabled(viewModel.isSaving || viewModel.thresholdText.isEmpty)
            }
        }
        .onAppear { viewModel.clearSaveError() }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CreatePercentAlertViewModelTests 2>&1 | tail -10
```
Expected: PASS — 4/4.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/CreatePercentAlertViewModel.swift \
        CryptoPortfolio/Features/Alerts/Presentation/PercentAlertFormView.swift \
        CryptoPortfolioTests/Alerts/Presentation/CreatePercentAlertViewModelTests.swift
git commit -m "feat(alerts): PercentAlertFormView + CreatePercentAlertViewModel

Per-coin percent-change alert form: 24h/7d/30d window, above/below
direction, decimal threshold (comma-normalised), recurrence picker.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Presentation — Portfolio form (value / P/L percent)

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/CreatePortfolioAlertViewModel.swift`
- Create: `CryptoPortfolio/Features/Alerts/Presentation/PortfolioAlertFormView.swift`
- Test: `CryptoPortfolioTests/Alerts/Presentation/CreatePortfolioAlertViewModelTests.swift` (new)

- [ ] **Step 1: Write failing VM tests**

Create `CryptoPortfolioTests/Alerts/Presentation/CreatePortfolioAlertViewModelTests.swift`:

```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreatePortfolioAlertViewModelTests: XCTestCase {
    private func makeVM(metric: CreatePortfolioAlertViewModel.Metric) -> (CreatePortfolioAlertViewModel, InMemoryAlertRepository) {
        let repo = InMemoryAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        let vm = CreatePortfolioAlertViewModel(metric: metric, createAlert: useCase)
        return (vm, repo)
    }

    func test_value_above_happyPath() async {
        let (vm, repo) = makeVM(metric: .value)
        vm.direction = .above
        vm.thresholdText = "100000"
        XCTAssertTrue(await vm.save())
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .portfolioValue(direction: .above, threshold: 100_000))
    }

    func test_value_rejectsNonPositiveTarget() async {
        let (vm, _) = makeVM(metric: .value)
        vm.thresholdText = "0"
        XCTAssertFalse(await vm.save())
        XCTAssertNotNil(vm.saveError)
    }

    func test_pnlPercent_below_happyPath_negative() async {
        let (vm, repo) = makeVM(metric: .pnlPercent)
        vm.direction = .below
        vm.thresholdText = "-10"
        XCTAssertTrue(await vm.save())
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .portfolioPnLPercent(direction: .below, threshold: -10))
    }

    func test_pnlPercent_rejectsZeroThreshold() async {
        let (vm, _) = makeVM(metric: .pnlPercent)
        vm.thresholdText = "0"
        XCTAssertFalse(await vm.save())
        XCTAssertNotNil(vm.saveError)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build-for-testing 2>&1 | tail -10
```
Expected: COMPILE FAILURE.

- [ ] **Step 3: Create the VM**

Create `CryptoPortfolio/Features/Alerts/Presentation/CreatePortfolioAlertViewModel.swift`:

```swift
import Foundation

@MainActor
final class CreatePortfolioAlertViewModel: ObservableObject {
    enum Metric: String, CaseIterable, Identifiable {
        case value, pnlPercent
        var id: String { rawValue }
    }

    let metric: Metric
    @Published var direction: AlertCondition.Direction = .above
    @Published var thresholdText: String = ""
    @Published var recurrence: RecurrencePickerState = RecurrencePickerState()
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let createAlert: CreateAlertUseCase

    init(metric: Metric, createAlert: CreateAlertUseCase) {
        self.metric = metric
        self.createAlert = createAlert
    }

    func save() async -> Bool {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let normalized = thresholdText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            saveError = String(localized: "createAlert.error.thresholdNotNumber",
                               defaultValue: "Threshold is not a number.")
            return false
        }

        let condition: AlertCondition
        switch metric {
        case .value:      condition = .portfolioValue(direction: direction, threshold: value)
        case .pnlPercent: condition = .portfolioPnLPercent(direction: direction, threshold: value)
        }

        do {
            try createAlert(condition: condition, recurrence: recurrence.recurrence)
            return true
        } catch AlertError.invalidPrice {
            saveError = String(localized: "createAlert.error.priceNotPositive",
                               defaultValue: "Target price must be greater than zero.")
            return false
        } catch AlertError.invalidThreshold {
            saveError = String(localized: "createAlert.error.thresholdZero",
                               defaultValue: "Threshold cannot be zero.")
            return false
        } catch {
            saveError = String(localized: "createAlert.error.saveFailed",
                               defaultValue: "Could not save alert.")
            return false
        }
    }

    func clearSaveError() { saveError = nil }
}
```

- [ ] **Step 4: Create `PortfolioAlertFormView.swift`**

Create `CryptoPortfolio/Features/Alerts/Presentation/PortfolioAlertFormView.swift`:

```swift
import SwiftUI

struct PortfolioAlertFormView: View {
    @StateObject private var viewModel: CreatePortfolioAlertViewModel
    let onSave: (Bool) -> Void

    init(metric: CreatePortfolioAlertViewModel.Metric,
         container: AppContainer,
         onSave: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreatePortfolioAlertViewModel(
            metric: metric,
            createAlert: container.makeCreateAlertUseCase()
        ))
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section {
                Picker("alerts.form.direction", selection: $viewModel.direction) {
                    Text("alerts.direction.above").tag(AlertCondition.Direction.above)
                    Text("alerts.direction.below").tag(AlertCondition.Direction.below)
                }
                .pickerStyle(.segmented)

                LabeledContent("alerts.form.threshold") {
                    TextField("0.0", text: $viewModel.thresholdText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(viewModel.metric == .value
                     ? "alerts.metric.value"
                     : "alerts.metric.pnlPercent")
            } footer: {
                if let error = viewModel.saveError {
                    Text(error).foregroundStyle(Theme.negative)
                }
            }

            RecurrencePickerView(state: $viewModel.recurrence)
        }
        .navigationTitle("alerts.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("alerts.create.save") {
                    Task {
                        let saved = await viewModel.save()
                        if saved { onSave(true) }
                    }
                }
                .disabled(viewModel.isSaving || viewModel.thresholdText.isEmpty)
            }
        }
        .onAppear { viewModel.clearSaveError() }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CreatePortfolioAlertViewModelTests 2>&1 | tail -10
```
Expected: PASS — 4/4.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/CreatePortfolioAlertViewModel.swift \
        CryptoPortfolio/Features/Alerts/Presentation/PortfolioAlertFormView.swift \
        CryptoPortfolioTests/Alerts/Presentation/CreatePortfolioAlertViewModelTests.swift
git commit -m "feat(alerts): PortfolioAlertFormView + CreatePortfolioAlertViewModel

Single form handles both portfolioValue and portfolioPnLPercent via Metric.
Per-variant validation surfaces localized errors.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Presentation — `AlertTypeChooserView` + final CreateAlertView routing

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/AlertTypeChooserView.swift`
- Modify: `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift`

This task has no new domain tests; it's pure routing/view composition. We verify behaviour with the existing app launch later in Task 17.

- [ ] **Step 1: Create `AlertTypeChooserView.swift`**

```swift
import SwiftUI

/// Root of the Create-Alert flow when the user did NOT come from CoinDetail's
/// shortcut. Lets the user pick which kind of alert they want to set up.
struct AlertTypeChooserView: View {
    let container: AppContainer
    let onDone: (Bool) -> Void

    var body: some View {
        List {
            Section("alerts.type.section.coin") {
                NavigationLink {
                    CoinSearchPickerView(container: container) { coin in
                        PriceAlertFormView(coin: coin, container: container, onSave: onDone)
                    }
                } label: {
                    typeRow(systemImage: "arrow.up.circle.fill",
                            titleKey: "alerts.type.priceCrossing",
                            descKey: "alerts.type.priceCrossing.desc")
                }
                NavigationLink {
                    CoinSearchPickerView(container: container) { coin in
                        PercentAlertFormView(coin: coin, container: container, onSave: onDone)
                    }
                } label: {
                    typeRow(systemImage: "chart.line.uptrend.xyaxis",
                            titleKey: "alerts.type.percentChange",
                            descKey: "alerts.type.percentChange.desc")
                }
            }
            Section("alerts.type.section.portfolio") {
                NavigationLink {
                    PortfolioAlertFormView(metric: .value, container: container, onSave: onDone)
                } label: {
                    typeRow(systemImage: "briefcase.fill",
                            titleKey: "alerts.type.portfolioValue",
                            descKey: "alerts.type.portfolioValue.desc")
                }
                NavigationLink {
                    PortfolioAlertFormView(metric: .pnlPercent, container: container, onSave: onDone)
                } label: {
                    typeRow(systemImage: "chart.pie.fill",
                            titleKey: "alerts.type.portfolioPnLPercent",
                            descKey: "alerts.type.portfolioPnLPercent.desc")
                }
            }
        }
        .navigationTitle("alerts.create.chooserTitle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func typeRow(systemImage: String,
                         titleKey: LocalizedStringKey,
                         descKey: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey).font(.body.weight(.semibold))
                Text(descKey).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Inline coin-search step used by the coin-bound alert types. Reuses the
/// search state we already had in CreateAlertViewModel.
struct CoinSearchPickerView<Destination: View>: View {
    let container: AppContainer
    let destination: (Coin) -> Destination

    @StateObject private var viewModel: CreateAlertViewModel

    init(container: AppContainer,
         @ViewBuilder destination: @escaping (Coin) -> Destination) {
        self.container = container
        self.destination = destination
        _viewModel = StateObject(wrappedValue: CreateAlertViewModel(
            searchCoins: container.makeSearchCoinsUseCase()
        ))
    }

    var body: some View {
        content
            .searchable(text: $viewModel.query, prompt: Text("alerts.create.search.prompt"))
            .onSubmit(of: .search) { Task { await viewModel.search() } }
            .navigationTitle("alerts.create.searchTitle")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.results {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(systemImage: "magnifyingglass",
                           titleKey: "alerts.create.empty.title",
                           messageKey: "alerts.create.empty.message")
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }
        case .loaded(let coins):
            List(coins) { coin in
                NavigationLink {
                    destination(coin)
                } label: {
                    coinRow(coin)
                }
            }
            .listStyle(.plain)
        }
    }

    private func coinRow(_ coin: Coin) -> some View {
        HStack(spacing: 12) {
            if let url = coin.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    default: Circle().fill(.secondary.opacity(0.2))
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle().fill(.secondary.opacity(0.2)).frame(width: 32, height: 32)
            }
            VStack(alignment: .leading) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Replace `CreateAlertView.swift` with chooser-rooted routing**

Replace the contents of `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift` with:

```swift
import SwiftUI

struct CreateAlertView: View {
    private let container: AppContainer
    private let initialCoin: Coin?
    let onDone: (_ didCreate: Bool) -> Void

    init(container: AppContainer, initialCoin: Coin? = nil, onDone: @escaping (Bool) -> Void) {
        self.container = container
        self.initialCoin = initialCoin
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            root
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone(false) }
                    }
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        if let coin = initialCoin {
            // CoinDetail shortcut: skip the chooser, jump straight to the
            // price-crossing form. Wrapping in a NavigationLink keeps the
            // back affordance consistent with the chooser path.
            PriceAlertFormView(coin: coin, container: container) { saved in onDone(saved) }
        } else {
            AlertTypeChooserView(container: container, onDone: onDone)
        }
    }
}
```

- [ ] **Step 3: Build the whole project to catch view-composition errors**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the full alert suite (sanity)**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/Alerts 2>&1 | tail -20
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/AlertTypeChooserView.swift \
        CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift
git commit -m "feat(alerts): AlertTypeChooserView + root routing

CreateAlertView now routes through AlertTypeChooserView; CoinDetail's
initialCoin shortcut bypasses the chooser straight to PriceAlertFormView.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Presentation — Polymorphic `AlertRow`

**Files:**
- Modify: `CryptoPortfolio/Features/Alerts/Presentation/AlertRow.swift`
- Test: existing `AlertRow` snapshot/structure tests if any (locate)

- [ ] **Step 1: Locate any existing AlertRow tests**

Run:
```bash
grep -RnE "AlertRow|class.*AlertRow" CryptoPortfolioTests/Alerts/Presentation
```
If tests exist, read them; preserve the behaviour they assert. If none, proceed.

- [ ] **Step 2: Replace `AlertRow.swift`**

Replace the contents of `CryptoPortfolio/Features/Alerts/Presentation/AlertRow.swift` with:

```swift
import SwiftUI

struct AlertRow: View {
    let alert: PriceAlert
    let currency: Currency
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTextKey)
                    .font(.body.weight(.semibold))
                if let secondary = secondaryTextKey {
                    Text(secondary).font(.subheadline).foregroundStyle(.secondary)
                }
                if let plain = primaryTextPlain {
                    Text(plain).font(.body.weight(.semibold))
                }
                Text(recurrenceLabelKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if alert.firedAt != nil {
                    Text("alerts.fired")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.positive)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { alert.isActive }, set: { onToggle($0) }))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Per-variant derivations

    private var iconView: some View {
        let (systemName, color): (String, Color) = {
            switch alert.condition {
            case .priceCrossing(_, let dir, _):
                return (dir == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        dir == .above ? Theme.positive : Theme.negative)
            case .percentChange(_, let dir, _, _):
                return (dir == .above ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        dir == .above ? Theme.positive : Theme.negative)
            case .portfolioValue:
                return ("briefcase.fill", Theme.accent)
            case .portfolioPnLPercent:
                return ("chart.pie.fill", Theme.accent)
            }
        }()
        return Image(systemName: systemName)
            .foregroundStyle(color)
            .font(.title2)
    }

    /// We split presentation into:
    ///   - `primaryTextKey`: a LocalizedStringKey for portfolio variants
    ///   - `primaryTextPlain`: a plain composed string for coin variants
    ///     (because the coin name + formatted price aren't a single key).
    /// Exactly one of the two is non-nil at a time.
    private var primaryTextKey: LocalizedStringKey {
        switch alert.condition {
        case .portfolioValue:        return "alerts.row.portfolioValue"
        case .portfolioPnLPercent:   return "alerts.row.portfolioPnLPercent"
        case .priceCrossing, .percentChange:
            return "" // overridden by primaryTextPlain
        }
    }

    private var primaryTextPlain: String? {
        switch alert.condition {
        case .priceCrossing(let coinId, _, let target):
            return "\(coinId.capitalized)  \(CurrencyFormatter.format(target, currency: currency))"
        case .percentChange(let coinId, _, let window, let threshold):
            let pct = String(format: "%@%%", "\(threshold)")
            return "\(coinId.capitalized)  \(pct) (\(windowSuffix(window)))"
        case .portfolioValue, .portfolioPnLPercent:
            return nil
        }
    }

    private var secondaryTextKey: LocalizedStringKey? {
        switch alert.condition {
        case .priceCrossing(_, let dir, _), .percentChange(_, let dir, _, _),
             .portfolioValue(let dir, _), .portfolioPnLPercent(let dir, _):
            return dir == .above ? "alerts.direction.above" : "alerts.direction.below"
        }
    }

    private var recurrenceLabelKey: LocalizedStringKey {
        switch alert.recurrence {
        case .oneShot:    return "alerts.recurrence.oneShot"
        case .cooldown:   return "alerts.recurrence.cooldown"
        case .onCrossing: return "alerts.recurrence.onCrossing"
        }
    }

    private func windowSuffix(_ window: AlertCondition.PercentWindow) -> String {
        switch window {
        case .h24: return String(localized: "alerts.window.h24", defaultValue: "24h")
        case .d7:  return String(localized: "alerts.window.d7",  defaultValue: "7d")
        case .d30: return String(localized: "alerts.window.d30", defaultValue: "30d")
        }
    }
}
```

> **Why two text paths?** SwiftUI's `Text(_:)` overloads make composing a
> *single* `LocalizedStringKey` from a coin id + a formatted price awkward.
> Using a plain string for the coin variants (formatted manually) keeps the
> row source simple while preserving full L10n for the portfolio variants.

- [ ] **Step 3: Build the project**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the full alert suite**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/Alerts 2>&1 | tail -20
```
Expected: PASS — including any existing AlertRow tests.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/AlertRow.swift
git commit -m "feat(alerts): polymorphic AlertRow

Per-variant icon, primary text (composed for coin variants, localized key
for portfolio variants), direction label, recurrence label, and the
existing Fired badge + active toggle.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: Presentation — Wire `AlertNotificationFormatter` into `AlertsViewModel`

**Files:**
- Modify: `CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift`

The foreground `evaluateNow` path in `AlertsViewModel` previously formatted notification bodies inline (mirroring the legacy `evaluateAndNotify` logic). After Task 9 it must defer to the shared formatter.

- [ ] **Step 1: Locate the inline formatting**

Run:
```bash
grep -n "crossed\|notifications.fire\|fire(title:" CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift
```

- [ ] **Step 2: Replace the inline `notifications.fire` block with the formatter**

Wherever the file currently builds title/body strings for a firing, replace those with:

```swift
let title = AlertNotificationFormatter.title(for: firing)
let body = AlertNotificationFormatter.body(for: firing, coinName: nil, currency: currency)
await notifications.fire(title: title, body: body, identifier: firing.alert.id.uuidString)
```

(If the file already delegates to `container.evaluateAndNotify(...)`, this task is a no-op — verify and skip.)

- [ ] **Step 3: Run the AlertsViewModel tests**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/Alerts/Presentation 2>&1 | tail -20
```
Expected: PASS — including any AlertsViewModel tests.

- [ ] **Step 4: Commit (only if Step 2 modified the file)**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift
git commit -m "refactor(alerts): route AlertsViewModel firings through AlertNotificationFormatter

Single source of truth for notification copy across foreground and BGTask.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: L10n keys + simulator launch + screenshot

**Files:**
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`
- Create: `docs/screenshots/v1.1-alerts-chooser.png` (after sim launch)

- [ ] **Step 1: Inspect the existing `.xcstrings` structure**

```bash
grep -A1 '"alerts.fired"' CryptoPortfolio/Resources/Localizable.xcstrings | head -10
```
Note the JSON shape so the new entries match.

- [ ] **Step 2: Add the new L10n entries**

The exact JSON entries to add (one per key) to `CryptoPortfolio/Resources/Localizable.xcstrings`. Each follows the existing pattern: top-level `"<key>"` in `"strings"` with `"localizations": { "en": { "stringUnit": { "state": "translated", "value": "<en>" } }, "tr": { ... } }`.

| Key | en | tr |
| --- | --- | --- |
| `alerts.create.chooserTitle` | New alert | Yeni uyarı |
| `alerts.type.section.coin` | Per coin | Coin başına |
| `alerts.type.section.portfolio` | Portfolio | Portföy |
| `alerts.type.priceCrossing` | Price threshold | Fiyat eşiği |
| `alerts.type.priceCrossing.desc` | Notify when a coin price crosses a target | Bir coin fiyatı hedefi geçince haber ver |
| `alerts.type.percentChange` | Percent change | Yüzde değişimi |
| `alerts.type.percentChange.desc` | Notify on 24h / 7d / 30d moves | 24s / 7g / 30g hareketlerde haber ver |
| `alerts.type.portfolioValue` | Portfolio value | Portföy değeri |
| `alerts.type.portfolioValue.desc` | Notify when total value crosses a target | Toplam değer hedefi geçince haber ver |
| `alerts.type.portfolioPnLPercent` | Portfolio P/L % | Portföy K/Z % |
| `alerts.type.portfolioPnLPercent.desc` | Notify when total P/L percent crosses a target | Toplam K/Z yüzdesi hedefi geçince haber ver |
| `alerts.recurrence.oneShot` | One shot | Tek sefer |
| `alerts.recurrence.cooldown` | Cooldown | Beklemeli |
| `alerts.recurrence.onCrossing` | On each crossing | Her geçişte |
| `alerts.cooldown.interval` | Interval | Aralık |
| `alerts.cooldown.1h` | 1 hour | 1 saat |
| `alerts.cooldown.6h` | 6 hours | 6 saat |
| `alerts.cooldown.24h` | 24 hours | 24 saat |
| `alerts.window.h24` | 24h | 24s |
| `alerts.window.d7` | 7d | 7g |
| `alerts.window.d30` | 30d | 30g |
| `alerts.metric.value` | Total value | Toplam değer |
| `alerts.metric.pnlPercent` | P/L percent | K/Z yüzde |
| `alerts.form.direction` | Direction | Yön |
| `alerts.form.recurrence` | Recurrence | Tekrar |
| `alerts.form.window` | Window | Pencere |
| `alerts.form.threshold` | Threshold | Eşik |
| `alerts.row.portfolioValue` | Portfolio total | Portföy toplamı |
| `alerts.row.portfolioPnLPercent` | Portfolio P/L | Portföy K/Z |
| `alerts.notification.title` | Price alert | Fiyat uyarısı |
| `alerts.notification.body.priceCrossing` | %@ crossed %@ | %@ %@ değerini geçti |
| `alerts.notification.body.percentChange` | %@ moved %@ in %@ | %@, %@ %@ içinde hareket etti |
| `alerts.notification.body.portfolioValue` | Portfolio total reached %@ | Portföy toplamı %@ değerine ulaştı |
| `alerts.notification.body.portfolioPnLPercent` | Portfolio P/L is now %@ | Portföy K/Z şimdi %@ |
| `createAlert.error.thresholdNotNumber` | Threshold is not a number. | Eşik bir sayı değil. |
| `createAlert.error.thresholdZero` | Threshold cannot be zero. | Eşik sıfır olamaz. |

Each entry follows this template (substitute key + values):

```json
"alerts.recurrence.oneShot" : {
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "One shot" } },
    "tr" : { "stringUnit" : { "state" : "translated", "value" : "Tek sefer" } }
  }
}
```

Keep the file's existing `sourceLanguage` (`"tr"`) and `version` (`"1.0"`) keys untouched.

- [ ] **Step 3: Build to verify no missing keys are referenced**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED, no warnings about untranslated strings (other than pre-existing ones outside this scope).

- [ ] **Step 4: Run the entire test suite**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test 2>&1 | tail -30
```
Expected: PASS — full suite green. Note the total test count; record it in the commit message.

- [ ] **Step 5: Launch the app on the simulator, navigate to Alerts → +**

Run:
```bash
xcrun simctl bootstatus "iPhone 17" -b 2>/dev/null || xcrun simctl boot "iPhone 17"
xcrun simctl install booted \
  $(xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
              -destination 'platform=iOS Simulator,name=iPhone 17' \
              -showBuildSettings build 2>/dev/null \
    | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2; exit}')
xcrun simctl launch booted com.example.CryptoPortfolio
```
(If the bundle id differs, look it up in `project.yml`.)

Manually tap the Alerts tab → tap the `+` button. You should land on `AlertTypeChooserView`. Take a screenshot:

```bash
xcrun simctl io booted screenshot docs/screenshots/v1.1-alerts-chooser.png
```

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Resources/Localizable.xcstrings docs/screenshots/v1.1-alerts-chooser.png
git commit -m "feat(alerts): L10n keys (tr+en) for v1.1 + chooser screenshot

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: Documentation refresh

**Files:**
- Modify: `docs/architecture.md`
- Modify: `README.md`

- [ ] **Step 1: Update architecture.md**

Append a new `## Advanced Alerts (v1.1)` section to `docs/architecture.md` summarising:

```markdown
## Advanced Alerts (v1.1)

Alerts are now polymorphic. `AlertCondition` has four variants
(`priceCrossing`, `percentChange`, `portfolioValue`, `portfolioPnLPercent`) and
each alert chooses a `Recurrence` (`oneShot`, `cooldown(seconds:)`, `onCrossing`).
Both enums are `Codable` and persist as JSON in dedicated columns on the v2
CDAlert schema; v1 rows decode through a legacy fallback that synthesises
`.priceCrossing + .oneShot`. `EvaluateAlertsUseCase` consolidates a single
markets fetch per pass, regardless of how the alert types mix, and runs the
recurrence state machine (`shouldFire` + `lastConditionResult`) per alert.
Notification copy lives in `AlertNotificationFormatter`. The Create-Alert flow
opens on `AlertTypeChooserView`; the CoinDetail "Create alert" shortcut still
jumps straight to `PriceAlertFormView`.
```

- [ ] **Step 2: Update README.md**

Under the Features section, add the v1.1 bullet:

```markdown
- **Advanced alerts (v1.1)** — price thresholds, 24h/7d/30d percent moves,
  portfolio value, and portfolio P/L percent. Per-alert recurrence: one-shot,
  cooldown, or on-each-crossing.
```

- [ ] **Step 3: Commit**

```bash
git add docs/architecture.md README.md
git commit -m "docs: refresh README + architecture for v1.1 Advanced Alerts

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (running the spec back against the plan)

**Spec coverage:**
- §4.1 `AlertCondition` + `requiredCoinIds` → Task 1.
- §4.2 `Recurrence` → Task 1.
- §4.3 refactored `PriceAlert` → Task 2.
- §4.4 backward-compat init → Task 2 (verified via `PriceAlertTests`).
- §4.5 `Coin` 7d/30d fields → Task 3.
- §5.1 CDAlert schema v2 → Task 5.
- §5.2 toDomain legacy fallback → Task 6 (covered by `test_legacyRow_withoutConditionJSON_…`).
- §5.3 save mirrors legacy columns for `.priceCrossing` → Task 6 implementation + visible from the round-trip tests.
- §5.4 CoinGecko + DTO + mapper → Task 4.
- §6.1 `CreateAlertUseCase` rewrite + overload + `.invalidThreshold` → Task 7.
- §6.2 `EvaluateAlertsUseCase` rewrite + state machine → Task 8.
- §7.1 navigation flow → Task 14 (chooser) + Task 11/12/13 (forms).
- §7.2 three form VMs → Tasks 11/12/13.
- §7.3 polymorphic `AlertRow` → Task 15.
- §7.4 notification formatter → Task 9.
- §7.5 ~15 L10n keys → Task 17 (table covers 36 keys including the 5 createAlert error keys; superset of the 15-ish spec sketch).
- §8 testing strategy → distributed across Tasks 1, 4, 6, 7, 8, 9, 10, 11, 12, 13, 15.
- §9 phasing — implementation order maps 1:1 onto the spec's 6 phases (T1-3 = phase 1; T4-6 = phase 2; T7-9 = phases 3-4; T10-15 = phase 5; T17-18 = phase 6).

**Placeholder scan:** No `TBD`/`TODO`/"similar to" hand-waves remain. Each step shows the actual code or command.

**Type consistency:** `AlertCondition.Direction`, `AlertCondition.PercentWindow`, `Recurrence.cooldown(seconds:)`, `PriceAlert(condition:recurrence:isActive:firedAt:lastConditionResult:)`, `CreateAlertUseCase(condition:recurrence:)`, `EvaluateAlertsUseCase(alertRepository:coinRepository:portfolioRepository:currency:)`, `CoinMarketDTO.priceChangePercentage7dInCurrency`, `Coin.priceChangePercentage7d/30d`, `AlertNotificationFormatter.body(for:coinName:currency:)`, `RecurrencePickerState.{kind,cooldownSeconds,recurrence}`, and `CreatePortfolioAlertViewModel.Metric.{value,pnlPercent}` are introduced once and referenced consistently across all later tasks.

**Notes on test totals:** v1.0 ended at 179. New tests added: AlertConditionTests (7), RecurrenceTests (3), PriceAlertTests (3), CoinTests (2), Network additions (5), CoreDataMigrationTests (1), AlertRepositoryImplTests additions (4), CreateAlertUseCaseTests additions (6), EvaluateAlertsUseCaseTests additions (12), AlertNotificationFormatterTests (5), RecurrencePickerStateTests (4), CreatePriceAlertViewModelTests (5), CreatePercentAlertViewModelTests (4), CreatePortfolioAlertViewModelTests (4). Net ~65 new tests → expected total ~244.
