# Crypto Portfolio Tracker — Faz 5: Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Local price alerts: create per-coin above/below thresholds, store them, evaluate against current prices, fire local notifications when crossed. Best-effort background refresh via `BGTaskScheduler`. Wire Alerts tab into RootView. Also addresses one Phase 4 deferred item: move shared test mocks out of `PortfolioUseCasesTests.swift` into `Support/Mocks.swift`.

**Architecture:** Clean Architecture continues. `AlertRepository` (feature-local protocol, Core Data impl) + use cases for CRUD + `EvaluateAlertsUseCase` (pure threshold-crossing logic). `NotificationService` protocol with `NoOpNotificationService` default and a real `UserNotificationsService` (iOS `UserNotifications`). The evaluation happens **on demand** (when AlertsView appears + user pulls to refresh + when sheet save completes) for v1; background `BGTaskScheduler` registration is added but the iOS-scheduled wake is acknowledged as best-effort and not extensively tested (environmental). Alerts are local-only — there is **no push pipeline**.

**Tech Stack:** Swift 5 mode, SwiftUI, iOS 16+, Core Data, Swift Concurrency, `UserNotifications`, `BackgroundTasks`, XCTest.

Reference spec: `docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` (§7 use cases, §8 Alerts, §10 alerts design).

## Existing types this plan consumes (already on `main`)
- Domain: `PriceAlert(id: UUID, coinId: String, targetPrice: Double, direction: .above|.below, isActive: Bool, firedAt: Date?)` — declared in Phase 1 (`Domain/Entities/PriceAlert.swift`); fully reused here.
- Currency, `Coin`, `WatchItem`, `Holding`, `PortfolioSummary`, `HoldingValuation`, `ChartPoint`, `PriceRange`.
- Repositories: `CoinRepository`, `PortfolioRepository`, `WatchlistRepository`.
- Use cases: Portfolio + Watchlist + CoinDetail sets (~13 total).
- DI: `AppContainer` with lazy repos + `make*UseCase()` factories. Currently `NoOpAnalytics`/`NoOpCrashReporter` defaults.
- Presentation: `ViewState<T>`, `CurrencyFormatter`, `PriceChangeLabel`, `EmptyStateView`, `ErrorStateView`; `AddCoinView`/`AmountEntryView` (template for "pick coin then form" pattern); `Localizable.xcstrings` has `tab.alerts`, `common.cancel`, `common.retry`, `common.comingSoon`.
- Error mapping: `error.userFacingMessage` via `APIError+UserFacingMessage.swift`.
- Test mocks: `MockCoinRepository`, `MockPortfolioRepository`, `MockWatchlistRepository` — currently inside `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift` (moved out in Task 2).

Build/test commands (simulator "iPhone 17"); `.xcodeproj` is generated and gitignored:
```
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## File Structure

| File | Responsibility |
| --- | --- |
| `CryptoPortfolio/Features/Alerts/Domain/AlertRepository.swift` | Protocol: alerts / alert(id:) / save / delete |
| `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/.../contents` (modify) | Adds `CDAlert` entity (id UUID unique) |
| `CryptoPortfolio/Features/Alerts/Data/AlertRepositoryImpl.swift` | Core Data-backed impl |
| `CryptoPortfolio/Features/Alerts/Domain/AlertError.swift` | `enum AlertError: Error { case invalidPrice }` |
| `CryptoPortfolio/Features/Alerts/Domain/UseCases/GetAlertsUseCase.swift` | Returns `[PriceAlert]` |
| `CryptoPortfolio/Features/Alerts/Domain/UseCases/CreateAlertUseCase.swift` | Validates + persists a new alert |
| `CryptoPortfolio/Features/Alerts/Domain/UseCases/DeleteAlertUseCase.swift` | Deletes by UUID |
| `CryptoPortfolio/Features/Alerts/Domain/UseCases/SetAlertActiveUseCase.swift` | Toggles `isActive` on one alert |
| `CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift` | Pure threshold-crossing logic; persists firings; returns `[AlertFiring]` |
| `CryptoPortfolio/Features/Alerts/Domain/AlertFiring.swift` | `AlertFiring(alert: PriceAlert, firedAt: Date)` |
| `CryptoPortfolio/Core/Notifications/NotificationService.swift` | Protocol + `NoOpNotificationService` |
| `CryptoPortfolio/Core/Notifications/UserNotificationsService.swift` | iOS `UNUserNotificationCenter` impl |
| `CryptoPortfolio/Core/DI/AppContainer.swift` (modify) | `alertRepository` lazy + `notifications` injectable + 5 factories + `evaluateAndNotify` helper |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift` | State machine: load / delete / toggleActive / evaluateNow |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertsView.swift` | Top-level Alerts screen + sheet to CreateAlert |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertRow.swift` | Row: coin + direction arrow + price + Toggle + fired badge |
| `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift` | Search + select + form-fill + save |
| `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift` | Search → pick → form |
| `CryptoPortfolio/Features/Alerts/Presentation/AlertConditionView.swift` | Form pushed after coin picked (direction + targetPrice) |
| `CryptoPortfolio/App/CryptoPortfolioApp.swift` (modify) | BGTaskScheduler register + production `UserNotificationsService` |
| `CryptoPortfolio/App/RootView.swift` (modify) | Wires Alerts tab to `AlertsView` |
| `CryptoPortfolio/Resources/Info.plist` (modify) | `BGTaskSchedulerPermittedIdentifiers` + `UIBackgroundModes` |
| `CryptoPortfolio/Resources/Localizable.xcstrings` (modify) | `alerts.*` keys |
| `CryptoPortfolioTests/Support/Mocks.swift` (created in T2) | Centralized mocks |
| `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift` (modify) | Drop the moved mocks |
| `CryptoPortfolioTests/**` | New tests for each Alerts task |
| `docs/screenshots/phase5-alerts-empty.png` | Visual verification |

---

### Task 1: `AlertRepository` protocol + `CDAlert` model + `AlertRepositoryImpl`

**Files:**
- Modify: `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents` (adds `CDAlert`; keeps the 3 existing entities)
- Create: `CryptoPortfolio/Features/Alerts/Domain/AlertRepository.swift`
- Create: `CryptoPortfolio/Features/Alerts/Data/AlertRepositoryImpl.swift`
- Test: `CryptoPortfolioTests/Alerts/Data/AlertRepositoryImplTests.swift`

- [ ] **Step 1: Add `CDAlert` to the Core Data model**

Replace the ENTIRE contents of `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents` with (adds CDAlert; keeps CDCachedCoin, CDHolding, CDWatchItem unchanged):
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
        <attribute name="coinId" optional="NO" attributeType="String"/>
        <attribute name="targetPrice" optional="NO" attributeType="Double" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="direction" optional="NO" attributeType="String" defaultValueString="above"/>
        <attribute name="isActive" optional="NO" attributeType="Boolean" defaultValueString="YES" usesScalarValueType="YES"/>
        <attribute name="firedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <uniquenessConstraints>
            <uniquenessConstraint>
                <constraint value="id"/>
            </uniquenessConstraint>
        </uniquenessConstraints>
    </entity>
</model>
```

- [ ] **Step 2: Create `AlertRepository.swift`**

`CryptoPortfolio/Features/Alerts/Domain/AlertRepository.swift`:
```swift
import Foundation

/// Persistence for price alerts (one row per id).
protocol AlertRepository {
    func alerts() throws -> [PriceAlert]
    func alert(id: UUID) throws -> PriceAlert?
    func save(_ alert: PriceAlert) throws   // upsert by id
    func delete(id: UUID) throws
}
```

- [ ] **Step 3: Write the failing test**

Create `CryptoPortfolioTests/Alerts/Data/AlertRepositoryImplTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class AlertRepositoryImplTests: XCTestCase {
    private func makeSUT() -> AlertRepositoryImpl {
        AlertRepositoryImpl(stack: CoreDataStack(inMemory: true))
    }

    func test_alerts_startsEmpty() throws {
        XCTAssertTrue(try makeSUT().alerts().isEmpty)
    }

    func test_save_thenAlerts_returnsSaved() throws {
        let sut = makeSUT()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        try sut.save(alert)

        let stored = try sut.alerts()

        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.coinId, "bitcoin")
        XCTAssertEqual(stored.first?.targetPrice, 50_000)
        XCTAssertEqual(stored.first?.direction, .above)
        XCTAssertTrue(stored.first?.isActive ?? false)
        XCTAssertNil(stored.first?.firedAt)
    }

    func test_save_withSameId_updatesInsteadOfDuplicating() throws {
        let sut = makeSUT()
        let id = UUID()
        try sut.save(PriceAlert(id: id, coinId: "bitcoin", targetPrice: 50_000, direction: .above))
        try sut.save(PriceAlert(id: id, coinId: "bitcoin", targetPrice: 60_000, direction: .above, isActive: false))

        let stored = try sut.alerts()

        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.targetPrice, 60_000)
        XCTAssertFalse(stored.first?.isActive ?? true)
    }

    func test_alert_returnsNilWhenAbsent_andValueWhenPresent() throws {
        let sut = makeSUT()
        let id = UUID()
        XCTAssertNil(try sut.alert(id: id))

        try sut.save(PriceAlert(id: id, coinId: "bitcoin", targetPrice: 50_000, direction: .below))

        XCTAssertEqual(try sut.alert(id: id)?.targetPrice, 50_000)
    }

    func test_delete_removesAlert() throws {
        let sut = makeSUT()
        let a = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let b = PriceAlert(coinId: "ethereum", targetPrice: 3_000, direction: .below)
        try sut.save(a)
        try sut.save(b)

        try sut.delete(id: a.id)

        XCTAssertEqual(try sut.alerts().map(\.coinId), ["ethereum"])
    }

    func test_firedAt_roundtripsCorrectly() throws {
        let sut = makeSUT()
        let firedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try sut.save(PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above, isActive: false, firedAt: firedAt))

        XCTAssertEqual(try sut.alerts().first?.firedAt, firedAt)
    }
}
```

- [ ] **Step 4: Run; confirm FAIL to compile**

`cd /Users/efekck/project/crypto-portfolio-tracker && xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/AlertRepositoryImplTests`
Expected: `cannot find 'AlertRepositoryImpl' in scope`.

- [ ] **Step 5: Create `AlertRepositoryImpl.swift`**

`CryptoPortfolio/Features/Alerts/Data/AlertRepositoryImpl.swift`:
```swift
import CoreData

/// Core Data-backed `AlertRepository`. Upserts by id.
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
        entity.coinId = alert.coinId
        entity.targetPrice = alert.targetPrice
        entity.direction = alert.direction.rawValue
        entity.isActive = alert.isActive
        entity.firedAt = alert.firedAt
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

    private static func toDomain(_ entity: CDAlert) -> PriceAlert? {
        guard let id = entity.id, let coinId = entity.coinId,
              let rawDirection = entity.direction,
              let direction = PriceAlert.Direction(rawValue: rawDirection)
        else { return nil }
        return PriceAlert(
            id: id,
            coinId: coinId,
            targetPrice: entity.targetPrice,
            direction: direction,
            isActive: entity.isActive,
            firedAt: entity.firedAt
        )
    }
}
```

- [ ] **Step 6: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/AlertRepositoryImplTests
xcodebuild ... test
```
Expected: AlertRepositoryImplTests 6/6; full suite **121 tests** (115 prior + 6 new), 0 failures.

- [ ] **Step 7: Commit**

```bash
git add CryptoPortfolio/Core/Persistence CryptoPortfolio/Features/Alerts/Domain/AlertRepository.swift CryptoPortfolio/Features/Alerts/Data CryptoPortfolioTests/Alerts/Data
git commit -m "feat: add CDAlert model and Core Data AlertRepository"
```

---

### Task 2: Move shared mocks to `CryptoPortfolioTests/Support/Mocks.swift`

A structural refactor — no test count change. Currently `MockCoinRepository`, `MockPortfolioRepository`, `MockWatchlistRepository` live inside `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift`. They are consumed across at least four test files. Move them out so the third feature (Alerts) can pick up a centralized home for its own mock.

**Files:**
- Create: `CryptoPortfolioTests/Support/Mocks.swift`
- Modify: `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift` (delete the moved mocks)

- [ ] **Step 1: Create `CryptoPortfolioTests/Support/Mocks.swift`**

Move the THREE classes verbatim from `PortfolioUseCasesTests.swift` into the new file. The file content is:
```swift
import Foundation
@testable import CryptoPortfolio

// MARK: - Coin

final class MockCoinRepository: CoinRepository {
    var searchResult: [Coin] = []
    var marketsResult: [Coin] = []
    var chartResult: [ChartPoint] = []
    var errorToThrow: Error?
    private(set) var lastSearchQuery: String?
    private(set) var lastChartRequest: (coinId: String, range: PriceRange, currency: Currency)?

    func searchCoins(query: String) async throws -> [Coin] {
        lastSearchQuery = query
        if let errorToThrow { throw errorToThrow }
        return searchResult
    }
    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        if let errorToThrow { throw errorToThrow }
        return marketsResult
    }
    func chart(coinId: String, range: PriceRange, currency: Currency) async throws -> [ChartPoint] {
        lastChartRequest = (coinId, range, currency)
        if let errorToThrow { throw errorToThrow }
        return chartResult
    }
}

// MARK: - Portfolio

final class MockPortfolioRepository: PortfolioRepository {
    var storage: [String: Holding] = [:]

    func holdings() throws -> [Holding] {
        storage.values.sorted { $0.coinId < $1.coinId }
    }
    func holding(coinId: String) throws -> Holding? { storage[coinId] }
    func save(_ holding: Holding) throws { storage[holding.coinId] = holding }
    func remove(coinId: String) throws { storage[coinId] = nil }
}

// MARK: - Watchlist

final class MockWatchlistRepository: WatchlistRepository {
    var storage: [String: WatchItem] = [:]
    var errorToThrow: Error?

    func items() throws -> [WatchItem] {
        if let errorToThrow { throw errorToThrow }
        return storage.values.sorted { $0.addedAt < $1.addedAt }
    }
    func isWatched(coinId: String) throws -> Bool {
        if let errorToThrow { throw errorToThrow }
        return storage[coinId] != nil
    }
    func add(coinId: String) throws {
        if let errorToThrow { throw errorToThrow }
        if storage[coinId] == nil { storage[coinId] = WatchItem(coinId: coinId) }
    }
    func remove(coinId: String) throws {
        if let errorToThrow { throw errorToThrow }
        storage[coinId] = nil
    }
}
```

- [ ] **Step 2: Delete the same three classes from `PortfolioUseCasesTests.swift`**

Open `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift`. Remove the three classes `MockCoinRepository`, `MockPortfolioRepository`, `MockWatchlistRepository` from this file. Leave the `PortfolioUseCasesTests: XCTestCase` class and the existing 5 tests inside it UNTOUCHED. The remaining file should consist of `import XCTest`, `@testable import CryptoPortfolio`, and the `PortfolioUseCasesTests` class only.

- [ ] **Step 3: Verify with grep that mocks now live in exactly one place**

Run:
```bash
grep -rln "class MockCoinRepository" CryptoPortfolioTests/
grep -rln "class MockPortfolioRepository" CryptoPortfolioTests/
grep -rln "class MockWatchlistRepository" CryptoPortfolioTests/
```
Expected: each grep prints exactly ONE path — `CryptoPortfolioTests/Support/Mocks.swift`.

- [ ] **Step 4: Build + full suite**

```
xcodegen generate
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **` AND `** TEST SUCCEEDED **` with **121 tests** (unchanged from T1), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolioTests/Support/Mocks.swift CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift
git commit -m "refactor: move shared test mocks to Support/Mocks.swift"
```

---

### Task 3: Alert CRUD use cases + `AlertError` + AppContainer factories

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Domain/AlertError.swift`
- Create: `CryptoPortfolio/Features/Alerts/Domain/UseCases/GetAlertsUseCase.swift`
- Create: `CryptoPortfolio/Features/Alerts/Domain/UseCases/CreateAlertUseCase.swift`
- Create: `CryptoPortfolio/Features/Alerts/Domain/UseCases/DeleteAlertUseCase.swift`
- Create: `CryptoPortfolio/Features/Alerts/Domain/UseCases/SetAlertActiveUseCase.swift`
- Modify: `CryptoPortfolio/Core/DI/AppContainer.swift` (add `alertRepository` lazy + 4 factories)
- Modify: `CryptoPortfolioTests/Support/Mocks.swift` (add `MockAlertRepository`)
- Test: `CryptoPortfolioTests/Alerts/Domain/AlertCRUDUseCasesTests.swift`
- Modify: `CryptoPortfolioTests/DI/AppContainerTests.swift`

- [ ] **Step 1: Add `MockAlertRepository` to `CryptoPortfolioTests/Support/Mocks.swift`**

APPEND inside the file (after `MockWatchlistRepository`):
```swift
// MARK: - Alerts

final class MockAlertRepository: AlertRepository {
    var storage: [UUID: PriceAlert] = [:]
    var errorToThrow: Error?

    func alerts() throws -> [PriceAlert] {
        if let errorToThrow { throw errorToThrow }
        return Array(storage.values)
    }
    func alert(id: UUID) throws -> PriceAlert? {
        if let errorToThrow { throw errorToThrow }
        return storage[id]
    }
    func save(_ alert: PriceAlert) throws {
        if let errorToThrow { throw errorToThrow }
        storage[alert.id] = alert
    }
    func delete(id: UUID) throws {
        if let errorToThrow { throw errorToThrow }
        storage[id] = nil
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `CryptoPortfolioTests/Alerts/Domain/AlertCRUDUseCasesTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class AlertCRUDUseCasesTests: XCTestCase {
    func test_getAlerts_delegatesToRepository() throws {
        let repo = MockAlertRepository()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        try repo.save(alert)
        let sut = GetAlertsUseCase(alertRepository: repo)

        XCTAssertEqual(try sut().count, 1)
    }

    func test_createAlert_savesNewAlert() throws {
        let repo = MockAlertRepository()
        let sut = CreateAlertUseCase(alertRepository: repo)

        try sut(coinId: "bitcoin", targetPrice: 50_000, direction: .above)

        XCTAssertEqual(try repo.alerts().count, 1)
        XCTAssertEqual(try repo.alerts().first?.targetPrice, 50_000)
    }

    func test_createAlert_throwsOnNonPositivePrice() {
        let repo = MockAlertRepository()
        let sut = CreateAlertUseCase(alertRepository: repo)

        XCTAssertThrowsError(try sut(coinId: "bitcoin", targetPrice: 0, direction: .above)) { error in
            XCTAssertEqual(error as? AlertError, .invalidPrice)
        }
    }

    func test_deleteAlert_removesAlert() throws {
        let repo = MockAlertRepository()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        try repo.save(alert)
        let sut = DeleteAlertUseCase(alertRepository: repo)

        try sut(id: alert.id)

        XCTAssertTrue(try repo.alerts().isEmpty)
    }

    func test_setAlertActive_togglesIsActive() throws {
        let repo = MockAlertRepository()
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above, isActive: true)
        try repo.save(alert)
        let sut = SetAlertActiveUseCase(alertRepository: repo)

        try sut(id: alert.id, isActive: false)

        XCTAssertEqual(try repo.alert(id: alert.id)?.isActive, false)
    }

    func test_setAlertActive_isNoOpForUnknownId() throws {
        let repo = MockAlertRepository()
        let sut = SetAlertActiveUseCase(alertRepository: repo)

        // Should not throw, should not mutate.
        try sut(id: UUID(), isActive: true)

        XCTAssertTrue(try repo.alerts().isEmpty)
    }
}
```

APPEND to `CryptoPortfolioTests/DI/AppContainerTests.swift` (inside the existing class):
```swift
    func test_buildsAlertUseCases() throws {
        let container = makeSUT()
        _ = container.makeGetAlertsUseCase()
        _ = container.makeCreateAlertUseCase()
        _ = container.makeDeleteAlertUseCase()
        _ = container.makeSetAlertActiveUseCase()
    }
```

- [ ] **Step 3: Run; confirm FAIL.**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/AlertCRUDUseCasesTests -only-testing:CryptoPortfolioTests/AppContainerTests`

- [ ] **Step 4: Create the use cases**

`CryptoPortfolio/Features/Alerts/Domain/AlertError.swift`:
```swift
import Foundation

enum AlertError: Error, Equatable {
    case invalidPrice
}
```

`CryptoPortfolio/Features/Alerts/Domain/UseCases/GetAlertsUseCase.swift`:
```swift
import Foundation

struct GetAlertsUseCase {
    let alertRepository: AlertRepository

    func callAsFunction() throws -> [PriceAlert] {
        try alertRepository.alerts()
    }
}
```

`CryptoPortfolio/Features/Alerts/Domain/UseCases/CreateAlertUseCase.swift`:
```swift
import Foundation

struct CreateAlertUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(coinId: String, targetPrice: Double, direction: PriceAlert.Direction) throws {
        guard targetPrice > 0 else { throw AlertError.invalidPrice }
        let alert = PriceAlert(coinId: coinId, targetPrice: targetPrice, direction: direction)
        try alertRepository.save(alert)
    }
}
```

`CryptoPortfolio/Features/Alerts/Domain/UseCases/DeleteAlertUseCase.swift`:
```swift
import Foundation

struct DeleteAlertUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(id: UUID) throws {
        try alertRepository.delete(id: id)
    }
}
```

`CryptoPortfolio/Features/Alerts/Domain/UseCases/SetAlertActiveUseCase.swift`:
```swift
import Foundation

struct SetAlertActiveUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(id: UUID, isActive: Bool) throws {
        guard var alert = try alertRepository.alert(id: id) else { return }
        alert.isActive = isActive
        try alertRepository.save(alert)
    }
}
```

- [ ] **Step 5: Extend `AppContainer`**

In `CryptoPortfolio/Core/DI/AppContainer.swift`, find the `// MARK: - Repositories` section. ADD after the existing `watchlistRepository` lazy:
```swift
    private(set) lazy var alertRepository: AlertRepository = AlertRepositoryImpl(stack: coreDataStack)
```
In the `// MARK: - Use case factories` section, APPEND at the end:
```swift
    func makeGetAlertsUseCase() -> GetAlertsUseCase {
        GetAlertsUseCase(alertRepository: alertRepository)
    }

    func makeCreateAlertUseCase() -> CreateAlertUseCase {
        CreateAlertUseCase(alertRepository: alertRepository)
    }

    func makeDeleteAlertUseCase() -> DeleteAlertUseCase {
        DeleteAlertUseCase(alertRepository: alertRepository)
    }

    func makeSetAlertActiveUseCase() -> SetAlertActiveUseCase {
        SetAlertActiveUseCase(alertRepository: alertRepository)
    }
```
Do NOT change other code in the file.

- [ ] **Step 6: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/AlertCRUDUseCasesTests -only-testing:CryptoPortfolioTests/AppContainerTests
xcodebuild ... test
```
Expected: AlertCRUDUseCasesTests 6/6; AppContainerTests 5/5 (4 prior + 1 new); full suite **128 tests** (121 prior + 7 new), 0 failures.

- [ ] **Step 7: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Domain CryptoPortfolio/Core/DI/AppContainer.swift CryptoPortfolioTests/Support/Mocks.swift CryptoPortfolioTests/Alerts/Domain CryptoPortfolioTests/DI/AppContainerTests.swift
git commit -m "feat: add Alert CRUD use cases and AppContainer factories"
```

---

### Task 4: `EvaluateAlertsUseCase` + `AlertFiring`

The threshold-crossing logic. Pure-ish use case: fetches active alerts (no `firedAt`), gets current prices via `CoinRepository.markets`, decides which crossed, persists `firedAt + isActive=false`, returns the firings.

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Domain/AlertFiring.swift`
- Create: `CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift`
- Modify: `CryptoPortfolio/Core/DI/AppContainer.swift` (1 more factory)
- Test: `CryptoPortfolioTests/Alerts/Domain/EvaluateAlertsUseCaseTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Alerts/Domain/EvaluateAlertsUseCaseTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class EvaluateAlertsUseCaseTests: XCTestCase {

    private let frozen = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSUT(alerts: [PriceAlert] = [], coins: [Coin] = [])
        -> (EvaluateAlertsUseCase, MockAlertRepository, MockCoinRepository) {
        let alertRepo = MockAlertRepository()
        for a in alerts { try? alertRepo.save(a) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        let sut = EvaluateAlertsUseCase(
            alertRepository: alertRepo, coinRepository: coinRepo, currency: .usd
        )
        return (sut, alertRepo, coinRepo)
    }

    func test_noActiveAlerts_returnsEmpty() async throws {
        let (sut, _, _) = makeSUT()
        let firings = try await sut(now: frozen)
        XCTAssertTrue(firings.isEmpty)
    }

    func test_inactiveAlertsAreSkipped() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above, isActive: false)
        let (sut, _, _) = makeSUT(alerts: [alert], coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)])

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty, "Inactive alerts must not fire")
    }

    func test_alreadyFiredAlertsAreSkipped() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above, isActive: true, firedAt: frozen)
        let (sut, _, _) = makeSUT(alerts: [alert], coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 60_000)])

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty, "Already-fired alerts must not fire again")
    }

    func test_aboveAlertFiresWhenPriceCrosses() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let (sut, repo, _) = makeSUT(
            alerts: [alert],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        )

        let firings = try await sut(now: frozen)

        XCTAssertEqual(firings.count, 1)
        XCTAssertEqual(firings.first?.firedAt, frozen)
        // Persisted with isActive false and firedAt set.
        let stored = try repo.alert(id: alert.id)
        XCTAssertEqual(stored?.isActive, false)
        XCTAssertEqual(stored?.firedAt, frozen)
    }

    func test_aboveAlertDoesNotFireWhenPriceBelowTarget() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 60_000, direction: .above)
        let (sut, _, _) = makeSUT(
            alerts: [alert],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        )

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty)
    }

    func test_belowAlertFiresWhenPriceAtOrBelow() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .below)
        let (sut, _, _) = makeSUT(
            alerts: [alert],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)]
        )

        let firings = try await sut(now: frozen)

        XCTAssertEqual(firings.count, 1)
    }

    func test_missingPrice_skipsAlert() async throws {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let (sut, _, _) = makeSUT(alerts: [alert], coins: []) // markets returned nothing

        let firings = try await sut(now: frozen)

        XCTAssertTrue(firings.isEmpty)
    }

    func test_multipleAlertsAcrossCoins_fireIndependently() async throws {
        let btcAlert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let ethAlert = PriceAlert(coinId: "ethereum", targetPrice: 3_000, direction: .below)
        let (sut, _, _) = makeSUT(
            alerts: [btcAlert, ethAlert],
            coins: [
                Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000),
                Coin(id: "ethereum", symbol: "eth", name: "Ethereum", currentPrice: 4_000)
            ]
        )

        let firings = try await sut(now: frozen)

        XCTAssertEqual(firings.count, 1, "Only the BTC above-40k fires; ETH 4000 is not below 3000")
        XCTAssertEqual(firings.first?.alert.coinId, "bitcoin")
    }
}
```

- [ ] **Step 2: Run; confirm FAIL.**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/EvaluateAlertsUseCaseTests`

- [ ] **Step 3: Create the types**

`CryptoPortfolio/Features/Alerts/Domain/AlertFiring.swift`:
```swift
import Foundation

/// An alert that crossed its threshold during evaluation.
struct AlertFiring: Equatable {
    let alert: PriceAlert
    let firedAt: Date
}
```

`CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift`:
```swift
import Foundation

/// Pure-ish evaluation: read active alerts → fetch current prices → decide crossings →
/// persist `firedAt`/`isActive=false` → return firings for the caller to notify.
struct EvaluateAlertsUseCase {
    let alertRepository: AlertRepository
    let coinRepository: CoinRepository
    let currency: Currency

    func callAsFunction(now: Date = Date()) async throws -> [AlertFiring] {
        let active = try alertRepository.alerts().filter { $0.isActive && $0.firedAt == nil }
        guard !active.isEmpty else { return [] }
        let coinIds = Array(Set(active.map(\.coinId)))
        let coins = try await coinRepository.markets(ids: coinIds, currency: currency)
        let priceById = Dictionary(coins.map { ($0.id, $0.currentPrice) }, uniquingKeysWith: { first, _ in first })

        var firings: [AlertFiring] = []
        for alert in active {
            guard let price = priceById[alert.coinId] else { continue }
            let crossed: Bool
            switch alert.direction {
            case .above: crossed = price >= alert.targetPrice
            case .below: crossed = price <= alert.targetPrice
            }
            guard crossed else { continue }
            var fired = alert
            fired.isActive = false
            fired.firedAt = now
            try alertRepository.save(fired)
            firings.append(AlertFiring(alert: fired, firedAt: now))
        }
        return firings
    }
}
```

- [ ] **Step 4: Add the AppContainer factory**

In `CryptoPortfolio/Core/DI/AppContainer.swift`, APPEND at the end of the Use case factories section:
```swift
    func makeEvaluateAlertsUseCase(currency: Currency = .default) -> EvaluateAlertsUseCase {
        EvaluateAlertsUseCase(alertRepository: alertRepository, coinRepository: coinRepository, currency: currency)
    }
```

- [ ] **Step 5: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/EvaluateAlertsUseCaseTests
xcodebuild ... test
```
Expected: EvaluateAlertsUseCaseTests 8/8; full suite **136 tests** (128 prior + 8 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Domain/AlertFiring.swift CryptoPortfolio/Features/Alerts/Domain/UseCases/EvaluateAlertsUseCase.swift CryptoPortfolio/Core/DI/AppContainer.swift CryptoPortfolioTests/Alerts/Domain/EvaluateAlertsUseCaseTests.swift
git commit -m "feat: add EvaluateAlertsUseCase with threshold-crossing logic"
```

---

### Task 5: `NotificationService` protocol + iOS impl + AppContainer wiring

**Files:**
- Create: `CryptoPortfolio/Core/Notifications/NotificationService.swift`
- Create: `CryptoPortfolio/Core/Notifications/UserNotificationsService.swift`
- Modify: `CryptoPortfolio/Core/DI/AppContainer.swift` (add stored `notifications`, default = `UserNotificationsService()`, allow override; add `evaluateAndNotify` helper)
- Test: `CryptoPortfolioTests/Notifications/NotificationServiceTests.swift`
- Modify: `CryptoPortfolioTests/DI/AppContainerTests.swift` (override notifications with NoOp in `makeSUT`)
- Modify: `CryptoPortfolioTests/Support/Mocks.swift` (add `SpyNotificationService` for VM tests later)

- [ ] **Step 1: Create the protocol + No-op**

`CryptoPortfolio/Core/Notifications/NotificationService.swift`:
```swift
import Foundation

/// Local notifications abstraction. Production uses `UserNotificationsService`;
/// tests inject `NoOpNotificationService` or a spy.
protocol NotificationService {
    func requestAuthorizationIfNeeded() async -> Bool
    func fire(title: String, body: String, identifier: String) async
}

struct NoOpNotificationService: NotificationService {
    func requestAuthorizationIfNeeded() async -> Bool { false }
    func fire(title: String, body: String, identifier: String) async {}
}
```

- [ ] **Step 2: Create the iOS implementation**

`CryptoPortfolio/Core/Notifications/UserNotificationsService.swift`:
```swift
import Foundation
import UserNotifications

final class UserNotificationsService: NotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func fire(title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await center.add(request)
    }
}
```

- [ ] **Step 3: Add a spy to `Mocks.swift`**

APPEND to `CryptoPortfolioTests/Support/Mocks.swift`:
```swift
// MARK: - Notifications

final class SpyNotificationService: NotificationService {
    var authorizationResult: Bool = true
    private(set) var authorizationCalls: Int = 0
    private(set) var firings: [(title: String, body: String, identifier: String)] = []

    func requestAuthorizationIfNeeded() async -> Bool {
        authorizationCalls += 1
        return authorizationResult
    }
    func fire(title: String, body: String, identifier: String) async {
        firings.append((title, body, identifier))
    }
}
```

- [ ] **Step 4: Extend `AppContainer`**

In `CryptoPortfolio/Core/DI/AppContainer.swift`:
1. Add a stored property `let notifications: NotificationService` (after `crashReporter`).
2. Extend the existing `init(...)` to accept it with default `UserNotificationsService()`:
   - Before refactor: `init(httpClient: HTTPClient? = nil, rateLimiter: ..., coreDataStack: ..., analytics: ..., crashReporter: ...)`
   - After refactor: add `, notifications: NotificationService = UserNotificationsService()` AT THE END of the parameter list, and `self.notifications = notifications` inside the init.
3. ADD a helper method (at the bottom of the class, before the closing brace):
```swift
    @MainActor
    @discardableResult
    func evaluateAndNotify(currency: Currency = .default) async -> Int {
        do {
            let firings = try await makeEvaluateAlertsUseCase(currency: currency)(now: Date())
            for firing in firings {
                await notifications.fire(
                    title: "Price alert",
                    body: "\(firing.alert.coinId.capitalized) crossed \(firing.alert.targetPrice)",
                    identifier: firing.alert.id.uuidString
                )
            }
            return firings.count
        } catch {
            return 0
        }
    }
```

- [ ] **Step 5: Update test helpers**

In `CryptoPortfolioTests/DI/AppContainerTests.swift`, change the existing `makeSUT()` to pass `notifications: NoOpNotificationService()` so test runs don't trigger real `UNUserNotificationCenter` calls:
```swift
    private func makeSUT() -> AppContainer {
        AppContainer(coreDataStack: CoreDataStack(inMemory: true), notifications: NoOpNotificationService())
    }
```
(If `makeSUT()` already exists, simply add the `notifications:` argument.)

- [ ] **Step 6: Write the failing test for the helper + add Notification tests**

Create `CryptoPortfolioTests/Notifications/NotificationServiceTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class NotificationServiceTests: XCTestCase {

    func test_noOpService_returnsFalseAndDoesNothing() async {
        let sut: NotificationService = NoOpNotificationService()
        let granted = await sut.requestAuthorizationIfNeeded()
        await sut.fire(title: "x", body: "y", identifier: "id")
        XCTAssertFalse(granted)
    }

    func test_spyRecordsFiringsAndAuthorizationCalls() async {
        let sut = SpyNotificationService()
        _ = await sut.requestAuthorizationIfNeeded()
        await sut.fire(title: "Hi", body: "Body", identifier: "id-1")
        XCTAssertEqual(sut.authorizationCalls, 1)
        XCTAssertEqual(sut.firings.count, 1)
        XCTAssertEqual(sut.firings.first?.identifier, "id-1")
    }

    func test_evaluateAndNotify_firesForCrossedAlerts() async throws {
        let stack = CoreDataStack(inMemory: true)
        let notifications = SpyNotificationService()
        let container = AppContainer(coreDataStack: stack, notifications: notifications)
        // Seed: one above alert at 40k for bitcoin.
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        try container.alertRepository.save(alert)
        // Override coin repo to return a current price of 50k via a tiny indirection:
        // Inject by replacing the lazy coinRepository with a stub. Since the property is
        // `private(set) lazy var`, swapping it directly in a test is acceptable.
        container.coinRepository = StubCoinRepository(price: 50_000)

        let count = await container.evaluateAndNotify(currency: .usd)

        XCTAssertEqual(count, 1)
        XCTAssertEqual(notifications.firings.count, 1)
        XCTAssertEqual(notifications.firings.first?.identifier, alert.id.uuidString)
    }
}

/// Minimal stub used only for this test — returns a single coin with the requested price.
private final class StubCoinRepository: CoinRepository {
    private let price: Double
    init(price: Double) { self.price = price }

    func searchCoins(query: String) async throws -> [Coin] { [] }
    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        ids.map { Coin(id: $0, symbol: $0, name: $0, currentPrice: price) }
    }
    func chart(coinId: String, range: PriceRange, currency: Currency) async throws -> [ChartPoint] { [] }
}
```

Important: `test_evaluateAndNotify_firesForCrossedAlerts` mutates the container's `coinRepository`. For this to compile, `AppContainer.coinRepository` must be reassignable. The existing declaration in `AppContainer.swift` is `private(set) lazy var coinRepository: CoinRepository = ...`. To allow this test to swap it, RELAX the access modifier to `internal(set)` ONLY for `coinRepository` (one tiny safe change). Make the same relaxation for `alertRepository` if you need to seed via the test (`container.alertRepository.save(...)` already works since `save` is a method on the protocol — no setter needed for that). Specifically: change ONLY the `coinRepository` declaration to `internal(set) lazy var coinRepository: CoinRepository = ...`. Leave all other repo declarations unchanged.

- [ ] **Step 7: Run targeted + full suite**

```
xcodegen generate
xcodebuild ... test -only-testing:CryptoPortfolioTests/NotificationServiceTests
xcodebuild ... test
```
Expected: NotificationServiceTests 3/3; full suite **139 tests** (136 prior + 3 new), 0 failures.

- [ ] **Step 8: Commit**

```bash
git add CryptoPortfolio/Core/Notifications CryptoPortfolio/Core/DI/AppContainer.swift CryptoPortfolioTests/Support/Mocks.swift CryptoPortfolioTests/DI/AppContainerTests.swift CryptoPortfolioTests/Notifications
git commit -m "feat: add NotificationService abstraction and evaluateAndNotify helper"
```

---

### Task 6: `AlertsViewModel`

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift`
- Test: `CryptoPortfolioTests/Alerts/Presentation/AlertsViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Alerts/Presentation/AlertsViewModelTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class AlertsViewModelTests: XCTestCase {

    private func makeSUT(alerts: [PriceAlert] = [], coins: [Coin] = [], error: Error? = nil)
        -> (AlertsViewModel, MockAlertRepository, MockCoinRepository, SpyNotificationService) {
        let alertRepo = MockAlertRepository()
        for a in alerts { try? alertRepo.save(a) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        coinRepo.errorToThrow = error
        let notifications = SpyNotificationService()
        let vm = AlertsViewModel(
            getAlerts: GetAlertsUseCase(alertRepository: alertRepo),
            deleteAlert: DeleteAlertUseCase(alertRepository: alertRepo),
            setActive: SetAlertActiveUseCase(alertRepository: alertRepo),
            evaluate: EvaluateAlertsUseCase(alertRepository: alertRepo, coinRepository: coinRepo, currency: .usd),
            notifications: notifications
        )
        return (vm, alertRepo, coinRepo, notifications)
    }

    func test_initialState_isLoading() {
        let (sut, _, _, _) = makeSUT()
        XCTAssertEqual(sut.state, .loading)
    }

    func test_load_setsEmptyForNoAlerts() async {
        let (sut, _, _, _) = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_load_setsLoadedWithAlerts() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let (sut, _, _, _) = makeSUT(alerts: [alert])

        await sut.load()

        if case .loaded(let list) = sut.state {
            XCTAssertEqual(list.map(\.id), [alert.id])
        } else {
            XCTFail("Expected .loaded, got \(sut.state)")
        }
    }

    func test_delete_removesAlertAndReloads() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above)
        let (sut, repo, _, _) = makeSUT(alerts: [alert])
        await sut.load()

        await sut.delete(id: alert.id)

        XCTAssertTrue(try repo.alerts().isEmpty)
        XCTAssertEqual(sut.state, .empty)
    }

    func test_setActive_togglesAlertAndReloads() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 50_000, direction: .above, isActive: true)
        let (sut, repo, _, _) = makeSUT(alerts: [alert])
        await sut.load()

        await sut.setActive(id: alert.id, isActive: false)

        XCTAssertEqual(try repo.alert(id: alert.id)?.isActive, false)
    }

    func test_evaluateNow_firesNotificationsForCrossedAlerts() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 40_000, direction: .above)
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, _, _, notifications) = makeSUT(alerts: [alert], coins: [coin])
        await sut.load()

        await sut.evaluateNow()

        XCTAssertEqual(notifications.firings.count, 1)
        XCTAssertEqual(notifications.firings.first?.identifier, alert.id.uuidString)
    }

    func test_evaluateNow_doesNotFireWhenNoCrossings() async {
        let alert = PriceAlert(coinId: "bitcoin", targetPrice: 60_000, direction: .above)
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, _, _, notifications) = makeSUT(alerts: [alert], coins: [coin])

        await sut.evaluateNow()

        XCTAssertTrue(notifications.firings.isEmpty)
    }
}
```

- [ ] **Step 2: Run; confirm FAIL to compile**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/AlertsViewModelTests`

- [ ] **Step 3: Create `AlertsViewModel.swift`**

`CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift`:
```swift
import Foundation

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[PriceAlert]> = .loading

    private let getAlerts: GetAlertsUseCase
    private let deleteAlertUseCase: DeleteAlertUseCase
    private let setActiveUseCase: SetAlertActiveUseCase
    private let evaluate: EvaluateAlertsUseCase
    private let notifications: NotificationService

    init(getAlerts: GetAlertsUseCase,
         deleteAlert: DeleteAlertUseCase,
         setActive: SetAlertActiveUseCase,
         evaluate: EvaluateAlertsUseCase,
         notifications: NotificationService) {
        self.getAlerts = getAlerts
        self.deleteAlertUseCase = deleteAlert
        self.setActiveUseCase = setActive
        self.evaluate = evaluate
        self.notifications = notifications
    }

    func load() async {
        state = .loading
        do {
            let alerts = try getAlerts()
            state = alerts.isEmpty ? .empty : .loaded(alerts)
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func delete(id: UUID) async {
        do {
            try deleteAlertUseCase(id: id)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func setActive(id: UUID, isActive: Bool) async {
        do {
            try setActiveUseCase(id: id, isActive: isActive)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func evaluateNow() async {
        do {
            let firings = try await evaluate(now: Date())
            for firing in firings {
                await notifications.fire(
                    title: "Price alert",
                    body: "\(firing.alert.coinId.capitalized) crossed \(firing.alert.targetPrice)",
                    identifier: firing.alert.id.uuidString
                )
            }
            if !firings.isEmpty { await load() }
        } catch {
            // Evaluation errors are non-fatal for v1; preserve current state.
        }
    }

    func requestNotificationPermission() async {
        _ = await notifications.requestAuthorizationIfNeeded()
    }
}
```

- [ ] **Step 4: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/AlertsViewModelTests
xcodebuild ... test
```
Expected: targeted 7/7; full suite **146 tests** (139 prior + 7 new), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/AlertsViewModel.swift CryptoPortfolioTests/Alerts/Presentation/AlertsViewModelTests.swift
git commit -m "feat: add AlertsViewModel with load/delete/setActive/evaluateNow"
```

---

### Task 7: `AlertsView` + `AlertRow` + L10n

UI; no unit tests; build verify.

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/AlertRow.swift`
- Create: `CryptoPortfolio/Features/Alerts/Presentation/AlertsView.swift`
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`

NOTE: `AlertsView` references `CreateAlertView` (created in Task 8). In THIS task, the `+` button toggles `isShowingCreate` but the `.sheet` modifier is OMITTED (added in Task 8 Step 5). This keeps Task 7 buildable alone.

- [ ] **Step 1: Create `AlertRow.swift`**

```swift
import SwiftUI

struct AlertRow: View {
    let alert: PriceAlert
    let currency: Currency
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            directionIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.coinId.capitalized)
                    .font(.body.weight(.semibold))
                HStack(spacing: 4) {
                    Text(directionLabel)
                    Text(CurrencyFormatter.format(alert.targetPrice, currency: currency))
                        .monospacedDigit()
                }
                .font(.subheadline)
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

    private var directionIcon: some View {
        Image(systemName: alert.direction == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            .foregroundStyle(alert.direction == .above ? Theme.positive : Theme.negative)
            .font(.title2)
    }

    private var directionLabel: LocalizedStringKey {
        alert.direction == .above ? "alerts.direction.above" : "alerts.direction.below"
    }
}
```

- [ ] **Step 2: Create `AlertsView.swift`** (no `.sheet` yet)

```swift
import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel
    private let container: AppContainer
    @State private var isShowingCreate = false

    init(container: AppContainer, currency: Currency = .default) {
        self.container = container
        _viewModel = StateObject(wrappedValue: AlertsViewModel(
            getAlerts: container.makeGetAlertsUseCase(),
            deleteAlert: container.makeDeleteAlertUseCase(),
            setActive: container.makeSetAlertActiveUseCase(),
            evaluate: container.makeEvaluateAlertsUseCase(currency: currency),
            notifications: container.notifications
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("alerts.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.evaluateNow() }
                .task {
                    await viewModel.requestNotificationPermission()
                    await viewModel.load()
                    await viewModel.evaluateNow()
                }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isShowingCreate = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("alerts.create.accessibility")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "bell.slash",
                titleKey: "alerts.empty.title",
                messageKey: "alerts.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let alerts):
            loadedList(alerts: alerts)
        }
    }

    private func loadedList(alerts: [PriceAlert]) -> some View {
        List {
            ForEach(alerts) { alert in
                AlertRow(alert: alert, currency: .default) { newValue in
                    Task { await viewModel.setActive(id: alert.id, isActive: newValue) }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(id: alert.id) }
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
```

- [ ] **Step 3: Add new L10n keys**

Add inside the top-level `"strings"` object of `CryptoPortfolio/Resources/Localizable.xcstrings`. Keep all existing keys intact.
```json
    "alerts.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Alerts" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Alarmlar" } }
      }
    },
    "alerts.empty.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "No price alerts" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Fiyat alarmı yok" } }
      }
    },
    "alerts.empty.message" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Tap + to create your first price alert." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "+ ile ilk fiyat alarmını oluştur." } }
      }
    },
    "alerts.create.accessibility" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Create alert" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Alarm oluştur" } }
      }
    },
    "alerts.direction.above" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Above" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Üstünde" } }
      }
    },
    "alerts.direction.below" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Below" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Altında" } }
      }
    },
    "alerts.fired" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Fired" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Tetiklendi" } }
      }
    },
    "common.delete" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Delete" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Sil" } }
      }
    }
```

- [ ] **Step 4: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **146 tests** (unchanged), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/AlertRow.swift CryptoPortfolio/Features/Alerts/Presentation/AlertsView.swift CryptoPortfolio/Resources/Localizable.xcstrings
git commit -m "feat: add AlertsView with row list, toggle active, and swipe-to-delete"
```

---

### Task 8: `CreateAlertViewModel` + `CreateAlertView` + `AlertConditionView` + L10n + wire sheet

Two-step UX (mirrors AddCoin → AmountEntry): `CreateAlertView` provides a search list; tapping a coin pushes `AlertConditionView` (direction picker + price field). Save returns to AlertsView and triggers reload.

**Files:**
- Create: `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift`
- Create: `CryptoPortfolio/Features/Alerts/Presentation/AlertConditionView.swift`
- Create: `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift`
- Modify: `CryptoPortfolio/Features/Alerts/Presentation/AlertsView.swift` (re-add `.sheet`)
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`
- Test: `CryptoPortfolioTests/Alerts/Presentation/CreateAlertViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Alerts/Presentation/CreateAlertViewModelTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreateAlertViewModelTests: XCTestCase {

    private func makeSUT(searchResult: [Coin] = [], searchError: Error? = nil)
        -> (CreateAlertViewModel, MockCoinRepository, MockAlertRepository) {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = searchResult
        coinRepo.errorToThrow = searchError
        let alertRepo = MockAlertRepository()
        let vm = CreateAlertViewModel(
            searchCoins: SearchCoinsUseCase(coinRepository: coinRepo),
            createAlert: CreateAlertUseCase(alertRepository: alertRepo)
        )
        return (vm, coinRepo, alertRepo)
    }

    func test_initialResults_areEmpty() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.results, .empty)
    }

    func test_search_setsLoadedWithHits() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")
        let (sut, _, _) = makeSUT(searchResult: [coin])
        sut.query = "bit"
        await sut.search()
        XCTAssertEqual(sut.results, .loaded([coin]))
    }

    func test_save_validAlert_returnsTrue_andPersists() async {
        let (sut, _, alertRepo) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .above, targetPriceText: "50000")

        XCTAssertTrue(saved)
        XCTAssertEqual(try alertRepo.alerts().count, 1)
        XCTAssertEqual(try alertRepo.alerts().first?.targetPrice, 50_000)
    }

    func test_save_normalisesCommaDecimal() async {
        let (sut, _, alertRepo) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .below, targetPriceText: "49999,50")

        XCTAssertTrue(saved)
        XCTAssertEqual(try alertRepo.alerts().first?.targetPrice, 49_999.5)
    }

    func test_save_invalidPrice_returnsFalse_andSetsError() async {
        let (sut, _, _) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .above, targetPriceText: "0")

        XCTAssertFalse(saved)
        XCTAssertNotNil(sut.saveError)
    }

    func test_save_unparseablePrice_returnsFalse() async {
        let (sut, _, _) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .above, targetPriceText: "abc")

        XCTAssertFalse(saved)
        XCTAssertNotNil(sut.saveError)
    }
}
```

- [ ] **Step 2: Run; confirm FAIL**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/CreateAlertViewModelTests`

- [ ] **Step 3: Create `CreateAlertViewModel.swift`**

```swift
import Foundation

@MainActor
final class CreateAlertViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let searchCoins: SearchCoinsUseCase
    private let createAlert: CreateAlertUseCase

    init(searchCoins: SearchCoinsUseCase, createAlert: CreateAlertUseCase) {
        self.searchCoins = searchCoins
        self.createAlert = createAlert
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

    /// Returns true if the alert was saved successfully.
    func save(coin: Coin, direction: PriceAlert.Direction, targetPriceText: String) async -> Bool {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let normalized = targetPriceText.replacingOccurrences(of: ",", with: ".")
        guard let price = Double(normalized) else {
            saveError = "Target price is not a number."
            return false
        }
        do {
            try createAlert(coinId: coin.id, targetPrice: price, direction: direction)
            return true
        } catch AlertError.invalidPrice {
            saveError = "Target price must be greater than zero."
            return false
        } catch {
            saveError = "Could not save alert."
            return false
        }
    }

    func clearSaveError() { saveError = nil }
}
```

- [ ] **Step 4: Create `AlertConditionView.swift`**

```swift
import SwiftUI

struct AlertConditionView: View {
    let coin: Coin
    @ObservedObject var viewModel: CreateAlertViewModel
    let onSave: (Bool) -> Void

    @State private var direction: PriceAlert.Direction = .above
    @State private var targetPriceText: String = ""

    var body: some View {
        Form {
            Section {
                Picker("alerts.create.direction", selection: $direction) {
                    Text("alerts.direction.above").tag(PriceAlert.Direction.above)
                    Text("alerts.direction.below").tag(PriceAlert.Direction.below)
                }
                .pickerStyle(.segmented)

                LabeledContent("alerts.create.targetPrice") {
                    TextField("0.00", text: $targetPriceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(coin.name)
            } footer: {
                if let error = viewModel.saveError {
                    Text(error).foregroundStyle(Theme.negative)
                }
            }
        }
        .navigationTitle("alerts.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("alerts.create.save") {
                    Task {
                        let saved = await viewModel.save(coin: coin, direction: direction, targetPriceText: targetPriceText)
                        if saved { onSave(true) }
                    }
                }
                .disabled(viewModel.isSaving || targetPriceText.isEmpty)
            }
        }
        .onAppear { viewModel.clearSaveError() }
    }
}
```

- [ ] **Step 5: Create `CreateAlertView.swift`**

```swift
import SwiftUI

struct CreateAlertView: View {
    @StateObject private var viewModel: CreateAlertViewModel
    let onDone: (_ didCreate: Bool) -> Void

    init(container: AppContainer, onDone: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: CreateAlertViewModel(
            searchCoins: container.makeSearchCoinsUseCase(),
            createAlert: container.makeCreateAlertUseCase()
        ))
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
                    AlertConditionView(coin: coin, viewModel: viewModel) { saved in onDone(saved) }
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

- [ ] **Step 6: Re-wire `AlertsView` to present the sheet**

In `CryptoPortfolio/Features/Alerts/Presentation/AlertsView.swift`, replace ONLY the `body` (keep init and other methods unchanged) with:
```swift
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("alerts.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.evaluateNow() }
                .task {
                    await viewModel.requestNotificationPermission()
                    await viewModel.load()
                    await viewModel.evaluateNow()
                }
                .sheet(isPresented: $isShowingCreate) {
                    CreateAlertView(container: container) { didCreate in
                        isShowingCreate = false
                        if didCreate {
                            Task {
                                await viewModel.load()
                                await viewModel.evaluateNow()
                            }
                        }
                    }
                }
        }
    }
```

- [ ] **Step 7: Add L10n keys**

Add inside `"strings"`:
```json
    "alerts.create.searchTitle" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Pick a coin" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Coin seç" } }
      }
    },
    "alerts.create.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "New alert" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Yeni alarm" } }
      }
    },
    "alerts.create.search.prompt" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Search a coin" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Coin ara" } }
      }
    },
    "alerts.create.empty.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Search to add a coin" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Coin eklemek için ara" } }
      }
    },
    "alerts.create.empty.message" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Type a coin name or symbol and press Search." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Coin adı veya sembolü yazıp Ara'ya bas." } }
      }
    },
    "alerts.create.direction" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Direction" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Yön" } }
      }
    },
    "alerts.create.targetPrice" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Target price" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Hedef fiyat" } }
      }
    },
    "alerts.create.save" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Save" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Kaydet" } }
      }
    }
```

- [ ] **Step 8: Run targeted + full suite**

```
xcodegen generate
xcodebuild ... test -only-testing:CryptoPortfolioTests/CreateAlertViewModelTests
xcodebuild ... test
```
Expected: targeted 6/6; full suite **152 tests** (146 prior + 6 new), 0 failures.

- [ ] **Step 9: Commit**

```bash
git add CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift CryptoPortfolio/Features/Alerts/Presentation/AlertConditionView.swift CryptoPortfolio/Features/Alerts/Presentation/CreateAlertView.swift CryptoPortfolio/Features/Alerts/Presentation/AlertsView.swift CryptoPortfolio/Resources/Localizable.xcstrings CryptoPortfolioTests/Alerts/Presentation/CreateAlertViewModelTests.swift
git commit -m "feat: add CreateAlertView and AlertConditionView with search-then-form flow"
```

---

### Task 9: BGTaskScheduler registration + RootView Alerts tab + Info.plist + launch + screenshot

**Files:**
- Modify: `CryptoPortfolio/Resources/Info.plist` (add `BGTaskSchedulerPermittedIdentifiers` + `UIBackgroundModes`)
- Modify: `CryptoPortfolio/App/CryptoPortfolioApp.swift` (register BGAppRefreshTask + use `UserNotificationsService`)
- Modify: `CryptoPortfolio/App/RootView.swift` (wire Alerts tab to `AlertsView`)
- Create: `docs/screenshots/phase5-alerts-empty.png` (best-effort)

- [ ] **Step 1: Modify `Info.plist`**

Open `CryptoPortfolio/Resources/Info.plist`. INSIDE the top-level `<dict>` (alongside the existing keys), add the following two entries (keep all existing entries intact):
```xml
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>com.foneria.cryptoportfolio.alerts.refresh</string>
    </array>
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>processing</string>
    </array>
```

- [ ] **Step 2: Replace the ENTIRE contents of `CryptoPortfolio/App/CryptoPortfolioApp.swift`**

```swift
import SwiftUI
import BackgroundTasks

@main
struct CryptoPortfolioApp: App {
    @State private var container = AppContainer(notifications: UserNotificationsService())

    private static let bgTaskIdentifier = "com.foneria.cryptoportfolio.alerts.refresh"

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil) { task in
            Self.handle(task: task as! BGAppRefreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appContainer, container)
                .onAppear { Self.scheduleNextBGRefresh() }
        }
    }

    // MARK: - Background refresh

    private static func scheduleNextBGRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private static func handle(task: BGAppRefreshTask) {
        scheduleNextBGRefresh()
        let container = AppContainer(notifications: UserNotificationsService())
        let workItem = Task {
            _ = await container.evaluateAndNotify(currency: .default)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { workItem.cancel() }
    }
}
```

NOTE: iOS BGTaskScheduler is environmental — actual wake timing is opaque and not guaranteed. The registered handler runs on a real device when iOS decides; in the simulator it is essentially non-functional. We accept this for v1.

- [ ] **Step 3: Replace the ENTIRE contents of `CryptoPortfolio/App/RootView.swift`**

```swift
import SwiftUI

struct RootView: View {
    @Environment(\.appContainer) private var container

    var body: some View {
        TabView {
            PortfolioView(container: container)
                .tabItem { Label("tab.portfolio", systemImage: "chart.pie.fill") }

            WatchlistView(container: container)
                .tabItem { Label("tab.watchlist", systemImage: "star.fill") }

            AlertsView(container: container)
                .tabItem { Label("tab.alerts", systemImage: "bell.fill") }
        }
    }
}

#Preview {
    RootView()
}
```

The private `PlaceholderTab` struct can be deleted now (no remaining users). Verify with grep:
```bash
grep -rn "PlaceholderTab" CryptoPortfolio/
```
Expected: empty.

- [ ] **Step 4: Build + full suite**

```
xcodegen generate
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **` AND `** TEST SUCCEEDED **` with 152 tests, 0 failures. Watch for any warning about `UIBackgroundModes` keys — they should compile through.

- [ ] **Step 5: Launch + capture screenshot (best-effort)**

```bash
cd /Users/efekck/project/crypto-portfolio-tracker
mkdir -p docs/screenshots
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build
APP_PATH="$(find build/Build/Products -name 'CryptoPortfolio.app' | head -1)"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.foneria.cryptoportfolio
sleep 3
# On iPhone 17 sim (1206x2622), tabs are at the bottom. Tap on tab 3 (Alerts).
# Tabs are split into thirds; tab 3 center x ≈ 1005.
xcrun simctl io booted tap 1005 2540 2>/dev/null || true
sleep 1
xcrun simctl io booted screenshot docs/screenshots/phase5-alerts-empty.png
file docs/screenshots/phase5-alerts-empty.png
```
If `simctl io booted tap` doesn't switch tabs in this Xcode version, the screenshot may capture Portfolio — still acceptable evidence the app launched cleanly. Note in the commit message if applicable.

NOTE: A first-launch system notification permission dialog may appear. Either dismiss it interactively or accept that the screenshot may show the permission alert overlaying the UI; the deliverable is "app launches + Alerts tab is wired."

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Resources/Info.plist CryptoPortfolio/App/CryptoPortfolioApp.swift CryptoPortfolio/App/RootView.swift docs/screenshots/
git status
git commit -m "feat: wire AlertsView into the Alerts tab; register BGTaskScheduler"
```
Between `git add` and `git commit`, confirm `git status` shows ONLY the source + screenshot changes. `build/`, `.xcodeproj/`, and `Config/Secrets.xcconfig` must NOT be staged.

---

## Self-Review

**1. Spec coverage (§7 use cases, §8 Alerts, §10 alerts design):**
- `AlertRepository` protocol + Core Data impl → Tasks 1 ✅
- `CreateAlertUseCase` (with `AlertError.invalidPrice`) → Task 3 ✅
- `EvaluateAlertsUseCase` (threshold-crossing, persists `firedAt`/`isActive`) → Task 4 ✅
- `GetAlertsUseCase` + `DeleteAlertUseCase` + `SetAlertActiveUseCase` → Task 3 ✅
- `NotificationService` abstraction + iOS impl → Task 5 ✅
- AlertsView (list + active toggle + swipe-to-delete + "+" → create form) → Tasks 7, 8 ✅
- CreateAlertView (coin search → direction + target price) → Task 8 ✅
- BGTaskScheduler registration → Task 9 ✅ (documented as best-effort, untested in suite)
- UserNotifications local notifications → Tasks 5, 6, 9 ✅
- Per spec §10, push pipeline NOT implemented (intentional) ✅
- L10n (tr/en) → Tasks 7, 8 ✅

Structural debt addressed (per Phase 4 deferred list):
- Shared mocks moved to `Support/Mocks.swift` → Task 2 ✅

Deliberately deferred (NOT in Phase 5):
- CoinDetail "Add to alert" quick action → Phase 7 polish.
- Auto-poll `PriceStreamService` → Phase 7.
- `ViewState.error` localization (still English literals) → Phase 7 L10n pass.
- Watchlist API-order vs `addedAt` sort fix → Phase 7 polish (Phase 4 deferred item).

**2. Placeholder scan:** No "TBD"/"TODO"/"add validation" placeholders. Every code step has complete code; every command has an expected output and a test count progression. The Task 9 screenshot step is genuinely best-effort and clearly marked.

**3. Type consistency:**
- `PriceAlert(id: UUID, coinId:, targetPrice:, direction:, isActive:, firedAt:)` init defaults remain unchanged from Phase 1 — used identically in Tasks 1, 3, 4, 6, 7, 8.
- `AlertRepository` methods (`alerts()/alert(id:)/save(_:)/delete(id:)`) identical across protocol (Task 1), impl (Task 1), `MockAlertRepository` (Task 3), and consumers (Tasks 3, 4, 6).
- `AlertError.invalidPrice` defined Task 3, caught in `CreateAlertViewModel.save` Task 8.
- `EvaluateAlertsUseCase(alertRepository:coinRepository:currency:)` + `callAsFunction(now:)` consistent across Tasks 4, 5 helper, 6.
- `NotificationService.requestAuthorizationIfNeeded() async -> Bool` and `fire(title:body:identifier:) async` consistent across protocol (Task 5), `NoOpNotificationService` (Task 5), `UserNotificationsService` (Task 5), `SpyNotificationService` (Task 5), and consumers (Tasks 5 helper, 6).
- `AppContainer.evaluateAndNotify(currency:)` (`@MainActor`, returns Int) consistent in Task 5 helper, Task 5 test, and Task 9's BG handler.
- `AppContainer.make*UseCase()` factory naming consistent with prior phases: `make{GetAlerts,CreateAlert,DeleteAlert,SetAlertActive,EvaluateAlerts}UseCase()` — used identically in Tasks 3, 4, 6, 7 (AlertsView init), 8 (CreateAlertView init).
- L10n keys `alerts.*` used by `AlertsView` (Task 7), `AlertRow` (Task 7), `CreateAlertView`/`AlertConditionView` (Task 8) match the keys added in Tasks 7 and 8.
- `Coin`, `Currency`, `PriceRange`, `ChartPoint` types unchanged from prior phases; consumed identically in stubs and tests.
- `AppContainer` init signature change (added trailing `notifications:` parameter) is backward compatible because the existing callers in prior tests (Phase 1-4) all use the no-argument or `coreDataStack:` form, which Swift fills with default `notifications: UserNotificationsService()`. Tests that need NoOp are updated in Tasks 5, 6 to pass `notifications: NoOpNotificationService()` / `SpyNotificationService()`.
- `internal(set)` relaxation on `coinRepository` (Task 5) is the only access-modifier change; it is required to let the helper-integration test in Task 5 swap the repo with a stub.
- Test count progression: 115 (start) → 121 (T1) → 121 (T2) → 128 (T3) → 136 (T4) → 139 (T5) → 146 (T6) → 146 (T7) → 152 (T8) → 152 (T9). ✅

No issues found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-01-crypto-portfolio-ios-phase5-alerts.md`.
