# Crypto Portfolio Tracker — Faz 4: Watchlist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Watchlist tab: a list of starred coins with live price + 24h change, plus search → star-toggle add/remove via a sheet. Tap → CoinDetail. Also addresses three structural debts before the third feature VM lands: `userFacingMessage` moves to `APIError` extension; feature views take `container: AppContainer` in init (cleaner RootView); and the established Phase 2b/3 patterns are propagated to Watchlist.

**Architecture:** Clean Architecture continues. New `WatchItem` domain entity + `WatchlistRepository` protocol + Core Data `CDWatchItem` impl (one row per coinId, uniqueness constraint). Use cases: `GetWatchlistUseCase` (returns `[Coin]` for watched ids via the shared `CoinRepository.markets(...)`) and `ToggleWatchlistUseCase` (add or remove). MVVM ViewModels mirror the Portfolio/AddCoin pattern. The container-injection refactor unifies all feature view inits to `init(container: AppContainer, …)`, eliminating ad-hoc use-case threading from RootView.

**Tech Stack:** Swift 5 mode, SwiftUI, iOS 16+, Core Data, Swift Concurrency, XCTest. No third-party deps.

Reference spec: `docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` (§5 layers, §6 data, §7 use cases, §8 Watchlist).

## Existing types this plan consumes (already on `main`)
- Domain: `Coin`, `Holding`, `ChartPoint(id:Int)`, `PriceRange`, `Currency`, `PortfolioSummary`, `HoldingValuation`.
- Repositories: `CoinRepository` (with `searchCoins`, `markets`, `chart`), `PortfolioRepository`.
- Use cases: `SearchCoinsUseCase`, `AddHoldingUseCase`, `RemoveHoldingUseCase`, `GetPortfolioSummaryUseCase`, `GetCoinChartUseCase`, `GetCoinMarketUseCase`.
- DI: `AppContainer` with `coinRepository`/`portfolioRepository` lazy + `make*UseCase()` factories.
- Presentation: `ViewState<T: Equatable>`, `CurrencyFormatter`, `PriceChangeLabel`, `EmptyStateView`, `ErrorStateView`; ViewModels (`PortfolioViewModel`, `AddCoinViewModel`, `CoinDetailViewModel`); Views (`PortfolioView`, `AddCoinView`, `AmountEntryView`, `CoinDetailView`, `RootView`).
- Test mocks: `MockCoinRepository` (with `errorToThrow`, `searchResult`, `marketsResult`, `chartResult`, `lastChartRequest`), `MockPortfolioRepository`.
- Currently: `PortfolioViewModel.userFacingMessage(for:)` is the cross-feature error mapper (reused by `AddCoinViewModel` and `CoinDetailViewModel`). Task 4 replaces it.
- `Localizable.xcstrings` has `tab.watchlist` already; new Watchlist UI keys are added in Tasks 7–8.

Build/test commands (simulator "iPhone 17"); `.xcodeproj` is generated and gitignored:
```
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## File Structure

| File | Responsibility |
| --- | --- |
| `CryptoPortfolio/Domain/Entities/WatchItem.swift` | `WatchItem(coinId:addedAt:)` value type |
| `CryptoPortfolio/Features/Watchlist/Domain/WatchlistRepository.swift` | Protocol: items / isWatched / add / remove |
| `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/.../contents` (modify) | Adds `CDWatchItem` entity (coinId unique, addedAt) |
| `CryptoPortfolio/Features/Watchlist/Data/WatchlistRepositoryImpl.swift` | Core Data-backed impl |
| `CryptoPortfolio/Features/Watchlist/Domain/UseCases/GetWatchlistUseCase.swift` | Returns `[Coin]` for watched ids |
| `CryptoPortfolio/Features/Watchlist/Domain/UseCases/ToggleWatchlistUseCase.swift` | Adds or removes by coinId |
| `CryptoPortfolio/Core/DI/AppContainer.swift` (modify) | `watchlistRepository` lazy + 2 use-case factories |
| `CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift` | `APIError.userFacingMessage` + `Error.userFacingMessage` |
| `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioViewModel.swift` (modify) | Drop static `userFacingMessage`; use `error.userFacingMessage` |
| `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift` (modify) | Use `error.userFacingMessage` |
| `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift` (modify) | Use `error.userFacingMessage` |
| `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift` (modify) | `init(container:currency:)`; sheet/NavigationLink use container |
| `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift` (modify) | `init(container:onDone:)` |
| `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift` (modify) | `init(coinId:coinName:currency:container:)` |
| `CryptoPortfolio/App/RootView.swift` (modify) | Passes `container` to each tab view |
| `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistViewModel.swift` | State machine: load/refresh/toggle |
| `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift` | Top-level Watchlist screen |
| `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistRow.swift` | Row subview: image + name + price + change |
| `CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistViewModel.swift` | Search + isWatched + toggle |
| `CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistView.swift` | Search sheet with star-toggle rows |
| `CryptoPortfolio/Resources/Localizable.xcstrings` (modify) | watchlist.* keys |
| `CryptoPortfolioTests/**` | Mirror tests for each task |
| `docs/screenshots/phase4-watchlist.png` | Visual verification |

---

### Task 1: `WatchItem` entity + `WatchlistRepository` protocol

**Files:**
- Create: `CryptoPortfolio/Domain/Entities/WatchItem.swift`
- Create: `CryptoPortfolio/Features/Watchlist/Domain/WatchlistRepository.swift`
- Test: `CryptoPortfolioTests/Domain/WatchItemTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Domain/WatchItemTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class WatchItemTests: XCTestCase {
    func test_idIsCoinId() {
        let item = WatchItem(coinId: "bitcoin", addedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(item.id, "bitcoin")
        XCTAssertEqual(item.coinId, "bitcoin")
    }

    func test_initDefaultsAddedAtToNow() {
        let before = Date()
        let item = WatchItem(coinId: "bitcoin")
        let after = Date()
        XCTAssertTrue(item.addedAt >= before && item.addedAt <= after)
    }
}
```

- [ ] **Step 2: Run; confirm FAIL to compile**

`cd /Users/efekck/project/crypto-portfolio-tracker && xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/WatchItemTests`
Expected: `cannot find 'WatchItem' in scope`.

- [ ] **Step 3: Create `WatchItem.swift`**

```swift
import Foundation

/// One starred coin in the user's watchlist.
struct WatchItem: Identifiable, Equatable {
    var id: String { coinId }
    let coinId: String
    let addedAt: Date

    init(coinId: String, addedAt: Date = Date()) {
        self.coinId = coinId
        self.addedAt = addedAt
    }
}
```

- [ ] **Step 4: Create `WatchlistRepository.swift`** (no test in this task; covered by impl in Task 2)

`CryptoPortfolio/Features/Watchlist/Domain/WatchlistRepository.swift`:
```swift
import Foundation

/// Persistence for the user's watchlist (one entry per coinId).
protocol WatchlistRepository {
    func items() throws -> [WatchItem]
    func isWatched(coinId: String) throws -> Bool
    func add(coinId: String) throws
    func remove(coinId: String) throws
}
```

- [ ] **Step 5: Run tests + commit**

`xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchItemTests` → 2 tests pass.
Full suite: `xcodebuild ... test` → **93 tests** (91 prior + 2 new), 0 failures.

```bash
git add CryptoPortfolio/Domain/Entities/WatchItem.swift CryptoPortfolio/Features/Watchlist/Domain/WatchlistRepository.swift CryptoPortfolioTests/Domain/WatchItemTests.swift
git commit -m "feat: add WatchItem entity and WatchlistRepository protocol"
```

---

### Task 2: `CDWatchItem` Core Data model + `WatchlistRepositoryImpl`

**Files:**
- Modify: `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents` (adds `CDWatchItem`; keep `CDCachedCoin` and `CDHolding`)
- Create: `CryptoPortfolio/Features/Watchlist/Data/WatchlistRepositoryImpl.swift`
- Test: `CryptoPortfolioTests/Watchlist/Data/WatchlistRepositoryImplTests.swift`

- [ ] **Step 1: Add `CDWatchItem` to the Core Data model**

Replace the ENTIRE contents of `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents` with (adds CDWatchItem; keeps the existing two entities unchanged):
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
</model>
```

- [ ] **Step 2: Write the failing test**

Create `CryptoPortfolioTests/Watchlist/Data/WatchlistRepositoryImplTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class WatchlistRepositoryImplTests: XCTestCase {
    private func makeSUT() -> WatchlistRepositoryImpl {
        WatchlistRepositoryImpl(stack: CoreDataStack(inMemory: true))
    }

    func test_items_startsEmpty() throws {
        let sut = makeSUT()
        XCTAssertTrue(try sut.items().isEmpty)
    }

    func test_add_thenItems_returnsWatchedCoin() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")

        let items = try sut.items()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.coinId, "bitcoin")
    }

    func test_add_isIdempotentForSameCoinId() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")
        try sut.add(coinId: "bitcoin")

        let items = try sut.items()

        XCTAssertEqual(items.count, 1, "Same coinId must not duplicate")
    }

    func test_isWatched_returnsTrueForAdded_andFalseForUnknown() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")

        XCTAssertTrue(try sut.isWatched(coinId: "bitcoin"))
        XCTAssertFalse(try sut.isWatched(coinId: "ethereum"))
    }

    func test_remove_deletesItem() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")
        try sut.add(coinId: "ethereum")

        try sut.remove(coinId: "bitcoin")

        XCTAssertEqual(try sut.items().map(\.coinId), ["ethereum"])
    }

    func test_items_sortedByAddedAtAscending() throws {
        let sut = makeSUT()
        // Use direct insertion via the impl in addedAt order via two sequential adds.
        try sut.add(coinId: "a")
        // Insert b after a small delay so addedAt is strictly later.
        Thread.sleep(forTimeInterval: 0.01)
        try sut.add(coinId: "b")

        let order = try sut.items().map(\.coinId)
        XCTAssertEqual(order, ["a", "b"])
    }
}
```

- [ ] **Step 3: Run; confirm FAIL to compile**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistRepositoryImplTests`
Expected: `cannot find 'WatchlistRepositoryImpl' in scope`.

- [ ] **Step 4: Create `WatchlistRepositoryImpl.swift`**

`CryptoPortfolio/Features/Watchlist/Data/WatchlistRepositoryImpl.swift`:
```swift
import CoreData

/// Core Data-backed `WatchlistRepository`. Idempotent add (one row per coinId).
final class WatchlistRepositoryImpl: WatchlistRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    private var context: NSManagedObjectContext { stack.viewContext }

    func items() throws -> [WatchItem] {
        let request = NSFetchRequest<CDWatchItem>(entityName: "CDWatchItem")
        request.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: true)]
        return try context.fetch(request).map(Self.toDomain)
    }

    func isWatched(coinId: String) throws -> Bool {
        try fetchEntity(coinId: coinId) != nil
    }

    func add(coinId: String) throws {
        if try fetchEntity(coinId: coinId) != nil { return }
        let entity = CDWatchItem(context: context)
        entity.coinId = coinId
        entity.addedAt = Date()
        try context.save()
    }

    func remove(coinId: String) throws {
        guard let entity = try fetchEntity(coinId: coinId) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - Helpers

    private func fetchEntity(coinId: String) throws -> CDWatchItem? {
        let request = NSFetchRequest<CDWatchItem>(entityName: "CDWatchItem")
        request.predicate = NSPredicate(format: "coinId == %@", coinId)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func toDomain(_ entity: CDWatchItem) -> WatchItem {
        WatchItem(coinId: entity.coinId ?? "", addedAt: entity.addedAt ?? Date())
    }
}
```

- [ ] **Step 5: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistRepositoryImplTests
xcodebuild ... test
```
Expected: targeted 6/6; full suite **99 tests** (93 prior + 6 new), 0 failures. The existing Phase 2 `PortfolioRepositoryImplTests` and `CoreDataStackTests` must still pass.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Core/Persistence CryptoPortfolio/Features/Watchlist/Data CryptoPortfolioTests/Watchlist/Data
git commit -m "feat: add CDWatchItem model and Core Data WatchlistRepository"
```

---

### Task 3: Use cases + `AppContainer` factories

**Files:**
- Create: `CryptoPortfolio/Features/Watchlist/Domain/UseCases/GetWatchlistUseCase.swift`
- Create: `CryptoPortfolio/Features/Watchlist/Domain/UseCases/ToggleWatchlistUseCase.swift`
- Modify: `CryptoPortfolio/Core/DI/AppContainer.swift`
- Modify: `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift` (add `MockWatchlistRepository`)
- Test: `CryptoPortfolioTests/Watchlist/Domain/WatchlistUseCasesTests.swift`
- Modify: `CryptoPortfolioTests/DI/AppContainerTests.swift`

- [ ] **Step 1: Add `MockWatchlistRepository` to the shared mocks file**

In `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift`, ADD this class at the top-level (alongside the existing `MockCoinRepository` and `MockPortfolioRepository`). Do not change the existing mocks or tests:
```swift
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
        if storage[coinId] == nil {
            storage[coinId] = WatchItem(coinId: coinId)
        }
    }
    func remove(coinId: String) throws {
        if let errorToThrow { throw errorToThrow }
        storage[coinId] = nil
    }
}
```

- [ ] **Step 2: Write the failing test**

Create `CryptoPortfolioTests/Watchlist/Domain/WatchlistUseCasesTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class WatchlistUseCasesTests: XCTestCase {

    func test_toggle_addsWhenNotWatched() throws {
        let repo = MockWatchlistRepository()
        let sut = ToggleWatchlistUseCase(watchlistRepository: repo)

        try sut(coinId: "bitcoin")

        XCTAssertTrue(try repo.isWatched(coinId: "bitcoin"))
    }

    func test_toggle_removesWhenAlreadyWatched() throws {
        let repo = MockWatchlistRepository()
        try repo.add(coinId: "bitcoin")
        let sut = ToggleWatchlistUseCase(watchlistRepository: repo)

        try sut(coinId: "bitcoin")

        XCTAssertFalse(try repo.isWatched(coinId: "bitcoin"))
    }

    func test_getWatchlist_returnsEmptyWhenNoItems() async throws {
        let watchRepo = MockWatchlistRepository()
        let coinRepo = MockCoinRepository()
        let sut = GetWatchlistUseCase(watchlistRepository: watchRepo, coinRepository: coinRepo)

        let coins = try await sut(currency: .usd)

        XCTAssertTrue(coins.isEmpty)
    }

    func test_getWatchlist_fetchesMarketsForWatchedIds() async throws {
        let watchRepo = MockWatchlistRepository()
        try watchRepo.add(coinId: "bitcoin")
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50000)]
        let sut = GetWatchlistUseCase(watchlistRepository: watchRepo, coinRepository: coinRepo)

        let coins = try await sut(currency: .usd)

        XCTAssertEqual(coins.map(\.id), ["bitcoin"])
        XCTAssertEqual(coins.first?.currentPrice, 50000)
    }
}
```

APPEND to `CryptoPortfolioTests/DI/AppContainerTests.swift` (inside the existing class):
```swift
    func test_buildsWatchlistUseCases() throws {
        let container = makeSUT()
        let get = container.makeGetWatchlistUseCase()
        let toggle = container.makeToggleWatchlistUseCase()
        XCTAssertNotNil(get); XCTAssertNotNil(toggle)
        _ = get; _ = toggle
    }
```

- [ ] **Step 3: Run; confirm FAIL**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistUseCasesTests -only-testing:CryptoPortfolioTests/AppContainerTests`
Expected: `cannot find 'ToggleWatchlistUseCase' / 'GetWatchlistUseCase' in scope`; AppContainer has no factories.

- [ ] **Step 4: Create the use cases**

`CryptoPortfolio/Features/Watchlist/Domain/UseCases/ToggleWatchlistUseCase.swift`:
```swift
import Foundation

struct ToggleWatchlistUseCase {
    let watchlistRepository: WatchlistRepository

    func callAsFunction(coinId: String) throws {
        if try watchlistRepository.isWatched(coinId: coinId) {
            try watchlistRepository.remove(coinId: coinId)
        } else {
            try watchlistRepository.add(coinId: coinId)
        }
    }
}
```

`CryptoPortfolio/Features/Watchlist/Domain/UseCases/GetWatchlistUseCase.swift`:
```swift
import Foundation

struct GetWatchlistUseCase {
    let watchlistRepository: WatchlistRepository
    let coinRepository: CoinRepository

    func callAsFunction(currency: Currency) async throws -> [Coin] {
        let items = try watchlistRepository.items()
        guard !items.isEmpty else { return [] }
        return try await coinRepository.markets(ids: items.map(\.coinId), currency: currency)
    }
}
```

- [ ] **Step 5: Extend `AppContainer`**

In `CryptoPortfolio/Core/DI/AppContainer.swift`, find the existing `// MARK: - Repositories (lazy, share the container's infrastructure)` section. ADD the following lazy property after the existing `portfolioRepository`:
```swift
    private(set) lazy var watchlistRepository: WatchlistRepository = WatchlistRepositoryImpl(stack: coreDataStack)
```
Then in the existing `// MARK: - Use case factories` section, APPEND these two methods at the end:
```swift
    func makeGetWatchlistUseCase() -> GetWatchlistUseCase {
        GetWatchlistUseCase(watchlistRepository: watchlistRepository, coinRepository: coinRepository)
    }

    func makeToggleWatchlistUseCase() -> ToggleWatchlistUseCase {
        ToggleWatchlistUseCase(watchlistRepository: watchlistRepository)
    }
```
Do NOT change any other code in `AppContainer.swift`.

- [ ] **Step 6: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistUseCasesTests -only-testing:CryptoPortfolioTests/AppContainerTests
xcodebuild ... test
```
Expected: WatchlistUseCasesTests 4/4; AppContainerTests 4/4 (3 prior + 1 new); full suite **104 tests** (99 prior + 5 new), 0 failures.

- [ ] **Step 7: Commit**

```bash
git add CryptoPortfolio/Features/Watchlist/Domain CryptoPortfolio/Core/DI/AppContainer.swift CryptoPortfolioTests/Watchlist/Domain CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift CryptoPortfolioTests/DI/AppContainerTests.swift
git commit -m "feat: add Watchlist use cases and AppContainer factories"
```

---

### Task 4: Refactor `userFacingMessage` to `APIError` extension

Removes the cross-feature dependency from the three existing VMs by moving the error→user-message mapping to an extension on `APIError` (+ a fallback on `Error`).

**Files:**
- Create: `CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift`
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioViewModel.swift` (drop static func; use `error.userFacingMessage`)
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift` (use `error.userFacingMessage`)
- Modify: `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift` (use `error.userFacingMessage`)
- Modify: `CryptoPortfolioTests/Portfolio/Presentation/PortfolioViewModelTests.swift` (the existing `test_load_setsErrorOnNetworkFailure` checks the message contains "rate" — no change needed if we preserve the same string).

- [ ] **Step 1: Create the extension**

`CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift`:
```swift
import Foundation

extension APIError {
    /// English fallback messages used when no localized error is in play.
    /// Phase 7 will replace these with `LocalizedStringKey`-backed strings.
    var userFacingMessage: String {
        switch self {
        case .rateLimited:                  return "Rate limited. Please try again in a moment."
        case .transport(let msg):           return "Network error: \(msg)"
        case .requestFailed(let code):      return "Server error (\(code))."
        case .decoding:                     return "Could not parse server response."
        case .invalidURL:                   return "Invalid request."
        }
    }
}

extension Error {
    /// Convenience: `APIError` instances get their tailored message; everything else
    /// falls back to a generic string. Keeps view-model error paths to a single line.
    var userFacingMessage: String {
        (self as? APIError)?.userFacingMessage ?? "Something went wrong."
    }
}
```

- [ ] **Step 2: Update `PortfolioViewModel.swift`**

Replace the ENTIRE contents of `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioViewModel.swift` with (removes `userFacingMessage(for:)`, uses `error.userFacingMessage`):
```swift
import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var state: ViewState<PortfolioSummary> = .loading

    private let getSummary: GetPortfolioSummaryUseCase
    private let removeHolding: RemoveHoldingUseCase
    let currency: Currency

    init(getSummary: GetPortfolioSummaryUseCase,
         removeHolding: RemoveHoldingUseCase,
         currency: Currency = .default) {
        self.getSummary = getSummary
        self.removeHolding = removeHolding
        self.currency = currency
    }

    func load() async {
        state = .loading
        do {
            let summary = try await getSummary(currency: currency)
            state = summary.items.isEmpty ? .empty : .loaded(summary)
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func refresh() async { await load() }

    func delete(coinId: String) async {
        do {
            try removeHolding(coinId: coinId)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }
}
```

- [ ] **Step 3: Update `AddCoinViewModel.swift`**

In `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift`, change the line:
```swift
            results = .error(PortfolioViewModel.userFacingMessage(for: error))
```
to:
```swift
            results = .error(error.userFacingMessage)
```
Leave everything else in the file (including `clearSaveError()` and the rest of `add(...)`/`search()`) exactly as it is.

- [ ] **Step 4: Update `CoinDetailViewModel.swift`**

In `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift`, change BOTH catch lines:
```swift
            headerState = .error(PortfolioViewModel.userFacingMessage(for: error))
```
and
```swift
            chartState = .error(PortfolioViewModel.userFacingMessage(for: error))
```
to:
```swift
            headerState = .error(error.userFacingMessage)
```
and
```swift
            chartState = .error(error.userFacingMessage)
```
respectively. Leave everything else in the file untouched.

- [ ] **Step 5: Build + run the FULL test suite**

```
xcodegen generate
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **` AND `** TEST SUCCEEDED **` with **104 tests**, 0 failures. The strings are byte-identical to the prior static func; the existing `PortfolioViewModelTests.test_load_setsErrorOnNetworkFailure` (which checks `.lowercased().contains("rate")`) continues to pass.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift CryptoPortfolio/Features/Portfolio/Presentation/PortfolioViewModel.swift CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift
git commit -m "refactor: move userFacingMessage to APIError extension; drop cross-VM coupling"
```

---

### Task 5: Container-injection refactor for feature views

Each top-level feature view now takes `container: AppContainer` in init and constructs its use cases internally. This eliminates the eager `make*UseCase()` chain in `RootView` and the NavigationLink destination, and unifies feature-view inits to a single shape.

**Files:**
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift`
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift`
- Modify: `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift`
- Modify: `CryptoPortfolio/App/RootView.swift`

- [ ] **Step 1: Replace the ENTIRE contents of `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift`**

```swift
import SwiftUI

struct PortfolioView: View {
    @StateObject private var viewModel: PortfolioViewModel
    private let container: AppContainer
    @State private var isShowingAddCoin = false

    init(container: AppContainer, currency: Currency = .default) {
        self.container = container
        _viewModel = StateObject(wrappedValue: PortfolioViewModel(
            getSummary: container.makeGetPortfolioSummaryUseCase(),
            removeHolding: container.makeRemoveHoldingUseCase(),
            currency: currency
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("portfolio.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.load() }
                .sheet(isPresented: $isShowingAddCoin) { addCoinSheet }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isShowingAddCoin = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("portfolio.addCoin.accessibility")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "chart.pie",
                titleKey: "portfolio.empty.title",
                messageKey: "portfolio.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let summary):
            loadedList(summary: summary)
        }
    }

    private func loadedList(summary: PortfolioSummary) -> some View {
        List {
            Section { PortfolioSummaryHeader(summary: summary, currency: viewModel.currency) }
            Section("portfolio.holdings.section") {
                ForEach(summary.items) { item in
                    NavigationLink {
                        CoinDetailView(
                            coinId: item.holding.coinId,
                            coinName: item.coin?.name ?? item.holding.coinId.capitalized,
                            currency: viewModel.currency,
                            container: container
                        )
                    } label: {
                        HoldingRow(valuation: item, currency: viewModel.currency)
                    }
                }
                .onDelete { indices in
                    let ids = indices.map { summary.items[$0].holding.coinId }
                    Task { for id in ids { await viewModel.delete(coinId: id) } }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var addCoinSheet: some View {
        AddCoinView(container: container) { saved in
            isShowingAddCoin = false
            if saved { Task { await viewModel.load() } }
        }
    }
}
```

- [ ] **Step 2: Replace the `init` of `AddCoinView`**

In `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift`, find the existing `init(searchCoins:addHolding:onDone:)` and the property right before it:
```swift
struct AddCoinView: View {
    @StateObject private var viewModel: AddCoinViewModel
    let onDone: (_ saved: Bool) -> Void

    init(searchCoins: SearchCoinsUseCase,
         addHolding: AddHoldingUseCase,
         onDone: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: AddCoinViewModel(
            searchCoins: searchCoins, addHolding: addHolding
        ))
        self.onDone = onDone
    }
```
Replace ONLY those lines with:
```swift
struct AddCoinView: View {
    @StateObject private var viewModel: AddCoinViewModel
    let onDone: (_ saved: Bool) -> Void

    init(container: AppContainer, onDone: @escaping (Bool) -> Void) {
        _viewModel = StateObject(wrappedValue: AddCoinViewModel(
            searchCoins: container.makeSearchCoinsUseCase(),
            addHolding: container.makeAddHoldingUseCase()
        ))
        self.onDone = onDone
    }
```
Leave the rest of the file (body, search list, navigation destinations, etc.) untouched.

- [ ] **Step 3: Replace the `init` of `CoinDetailView`**

In `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift`, find the existing `init`:
```swift
    init(coinId: String,
         coinName: String,
         currency: Currency,
         getCoinMarket: GetCoinMarketUseCase,
         getCoinChart: GetCoinChartUseCase) {
        _viewModel = StateObject(wrappedValue: CoinDetailViewModel(
            coinId: coinId, currency: currency,
            getCoinMarket: getCoinMarket, getCoinChart: getCoinChart
        ))
        self.coinName = coinName
    }
```
Replace ONLY this init with:
```swift
    init(coinId: String,
         coinName: String,
         currency: Currency,
         container: AppContainer) {
        _viewModel = StateObject(wrappedValue: CoinDetailViewModel(
            coinId: coinId, currency: currency,
            getCoinMarket: container.makeGetCoinMarketUseCase(),
            getCoinChart: container.makeGetCoinChartUseCase()
        ))
        self.coinName = coinName
    }
```
Leave the rest of the file untouched.

- [ ] **Step 4: Replace the ENTIRE contents of `CryptoPortfolio/App/RootView.swift`**

```swift
import SwiftUI

struct RootView: View {
    @Environment(\.appContainer) private var container

    var body: some View {
        TabView {
            PortfolioView(container: container)
                .tabItem { Label("tab.portfolio", systemImage: "chart.pie.fill") }

            PlaceholderTab(titleKey: "tab.watchlist", systemImage: "star.fill")
                .tabItem { Label("tab.watchlist", systemImage: "star.fill") }

            PlaceholderTab(titleKey: "tab.alerts", systemImage: "bell.fill")
                .tabItem { Label("tab.alerts", systemImage: "bell.fill") }
        }
    }
}

private struct PlaceholderTab: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(titleKey)
                .font(.title2.bold())
            Text("common.comingSoon")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
```

(Watchlist tab still placeholder — wired in Task 9.)

- [ ] **Step 5: Build + full suite**

```
xcodegen generate
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **` AND `** TEST SUCCEEDED **` with 104 tests, 0 failures. No new tests are added — the change is internal restructuring; views are not unit-tested.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift CryptoPortfolio/App/RootView.swift
git commit -m "refactor: feature views take AppContainer in init; simplify RootView"
```

---

### Task 6: `WatchlistViewModel`

**Files:**
- Create: `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistViewModel.swift`
- Test: `CryptoPortfolioTests/Watchlist/Presentation/WatchlistViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Watchlist/Presentation/WatchlistViewModelTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class WatchlistViewModelTests: XCTestCase {

    private func makeSUT(watched: [String] = [], coins: [Coin] = [], error: Error? = nil)
        -> (WatchlistViewModel, MockWatchlistRepository, MockCoinRepository) {
        let watchRepo = MockWatchlistRepository()
        for id in watched { try? watchRepo.add(coinId: id) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        coinRepo.errorToThrow = error
        let vm = WatchlistViewModel(
            getWatchlist: GetWatchlistUseCase(watchlistRepository: watchRepo, coinRepository: coinRepo),
            toggleWatchlist: ToggleWatchlistUseCase(watchlistRepository: watchRepo),
            currency: .usd
        )
        return (vm, watchRepo, coinRepo)
    }

    func test_initialState_isLoading() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.state, .loading)
    }

    func test_load_setsEmptyForNoWatchedItems() async {
        let (sut, _, _) = makeSUT()
        await sut.load()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_load_setsLoadedWithCoins() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, _, _) = makeSUT(watched: ["bitcoin"], coins: [coin])

        await sut.load()

        XCTAssertEqual(sut.state, .loaded([coin]))
    }

    func test_load_setsErrorOnNetworkFailure() async {
        let (sut, _, _) = makeSUT(watched: ["bitcoin"], coins: [], error: APIError.rateLimited)
        await sut.load()
        if case .error = sut.state { } else { XCTFail("Expected .error") }
    }

    func test_toggle_removesWatchedAndReloads() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let (sut, watchRepo, _) = makeSUT(watched: ["bitcoin"], coins: [coin])
        await sut.load()

        await sut.toggle(coinId: "bitcoin")

        XCTAssertFalse(try watchRepo.isWatched(coinId: "bitcoin"))
        XCTAssertEqual(sut.state, .empty)
    }
}
```

- [ ] **Step 2: Run; confirm FAIL to compile**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistViewModelTests`

- [ ] **Step 3: Create `WatchlistViewModel.swift`**

```swift
import Foundation

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Coin]> = .loading

    private let getWatchlist: GetWatchlistUseCase
    private let toggleWatchlist: ToggleWatchlistUseCase
    let currency: Currency

    init(getWatchlist: GetWatchlistUseCase,
         toggleWatchlist: ToggleWatchlistUseCase,
         currency: Currency = .default) {
        self.getWatchlist = getWatchlist
        self.toggleWatchlist = toggleWatchlist
        self.currency = currency
    }

    func load() async {
        state = .loading
        do {
            let coins = try await getWatchlist(currency: currency)
            state = coins.isEmpty ? .empty : .loaded(coins)
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func refresh() async { await load() }

    func toggle(coinId: String) async {
        do {
            try toggleWatchlist(coinId: coinId)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }
}
```

- [ ] **Step 4: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistViewModelTests
xcodebuild ... test
```
Expected: targeted 5/5; full suite **109 tests** (104 prior + 5 new), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Watchlist/Presentation/WatchlistViewModel.swift CryptoPortfolioTests/Watchlist/Presentation/WatchlistViewModelTests.swift
git commit -m "feat: add WatchlistViewModel with load/refresh/toggle state machine"
```

---

### Task 7: `WatchlistView` + `WatchlistRow` + L10n

UI; no unit tests. Build + full-suite verification only.

**Files:**
- Create: `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistRow.swift`
- Create: `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift`
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`

NOTE: `WatchlistView` references `AddToWatchlistView` (created in Task 8). In THIS task, do not yet include the sheet — the `+` button is present but stubbed. Task 8 re-wires the sheet.

- [ ] **Step 1: Create `WatchlistRow.swift`**

```swift
import SwiftUI

struct WatchlistRow: View {
    let coin: Coin
    let currency: Currency

    var body: some View {
        HStack(spacing: 12) {
            coinImage
            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(coin.currentPrice, currency: currency))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                PriceChangeLabel(percent: coin.priceChangePercentage24h)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var coinImage: some View {
        if let url = coin.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                default: Circle().fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            Circle().fill(.secondary.opacity(0.2)).frame(width: 36, height: 36)
        }
    }
}
```

- [ ] **Step 2: Create `WatchlistView.swift`** (no sheet yet)

```swift
import SwiftUI

struct WatchlistView: View {
    @StateObject private var viewModel: WatchlistViewModel
    private let container: AppContainer
    @State private var isShowingAddSheet = false

    init(container: AppContainer, currency: Currency = .default) {
        self.container = container
        _viewModel = StateObject(wrappedValue: WatchlistViewModel(
            getWatchlist: container.makeGetWatchlistUseCase(),
            toggleWatchlist: container.makeToggleWatchlistUseCase(),
            currency: currency
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("watchlist.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.load() }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isShowingAddSheet = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("watchlist.addCoin.accessibility")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "star.slash",
                titleKey: "watchlist.empty.title",
                messageKey: "watchlist.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let coins):
            loadedList(coins: coins)
        }
    }

    private func loadedList(coins: [Coin]) -> some View {
        List {
            ForEach(coins) { coin in
                NavigationLink {
                    CoinDetailView(
                        coinId: coin.id,
                        coinName: coin.name,
                        currency: viewModel.currency,
                        container: container
                    )
                } label: {
                    WatchlistRow(coin: coin, currency: viewModel.currency)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.toggle(coinId: coin.id) }
                    } label: {
                        Label("watchlist.unwatch", systemImage: "star.slash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
```

- [ ] **Step 3: Add new L10n keys to `Localizable.xcstrings`**

Add these 6 entries inside the top-level `"strings"` object. Keep all existing keys intact and use valid JSON commas.
```json
    "watchlist.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Watchlist" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "İzleme" } }
      }
    },
    "watchlist.empty.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "No watched coins" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "İzlenen coin yok" } }
      }
    },
    "watchlist.empty.message" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Tap + to search and star coins you want to follow." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "+ ile takip etmek istediğin coinleri ara ve yıldızla." } }
      }
    },
    "watchlist.addCoin.accessibility" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Add coin to watchlist" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "İzleme listesine coin ekle" } }
      }
    },
    "watchlist.unwatch" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Unstar" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Yıldızı kaldır" } }
      }
    },
    "watchlist.search.prompt" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Search a coin" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Coin ara" } }
      }
    }
```

- [ ] **Step 4: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **109 tests** (unchanged), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Watchlist/Presentation/WatchlistRow.swift CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift CryptoPortfolio/Resources/Localizable.xcstrings
git commit -m "feat: add WatchlistView with row list, empty/error states, and swipe-to-unstar"
```

---

### Task 8: `AddToWatchlistViewModel` + `AddToWatchlistView`

**Files:**
- Create: `CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistViewModel.swift`
- Create: `CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistView.swift`
- Modify: `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift` (re-add sheet)
- Test: `CryptoPortfolioTests/Watchlist/Presentation/AddToWatchlistViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Watchlist/Presentation/AddToWatchlistViewModelTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

@MainActor
final class AddToWatchlistViewModelTests: XCTestCase {

    private func makeSUT(searchResult: [Coin] = [], initiallyWatched: [String] = [], searchError: Error? = nil)
        -> (AddToWatchlistViewModel, MockCoinRepository, MockWatchlistRepository) {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = searchResult
        coinRepo.errorToThrow = searchError
        let watchRepo = MockWatchlistRepository()
        for id in initiallyWatched { try? watchRepo.add(coinId: id) }
        let vm = AddToWatchlistViewModel(
            searchCoins: SearchCoinsUseCase(coinRepository: coinRepo),
            toggleWatchlist: ToggleWatchlistUseCase(watchlistRepository: watchRepo),
            watchlistRepository: watchRepo
        )
        return (vm, coinRepo, watchRepo)
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

    func test_search_blankQueryStaysEmpty() async {
        let (sut, coinRepo, _) = makeSUT()
        sut.query = "   "
        await sut.search()
        XCTAssertEqual(sut.results, .empty)
        XCTAssertNil(coinRepo.lastSearchQuery)
    }

    func test_isWatched_reflectsRepositoryState() async {
        let (sut, _, _) = makeSUT(initiallyWatched: ["bitcoin"])
        await sut.refreshWatchedIds()
        XCTAssertTrue(sut.isWatched(coinId: "bitcoin"))
        XCTAssertFalse(sut.isWatched(coinId: "ethereum"))
    }

    func test_toggle_addsWhenNotWatched_andRefreshesState() async {
        let (sut, _, watchRepo) = makeSUT()
        await sut.toggle(coinId: "bitcoin")
        XCTAssertTrue(try watchRepo.isWatched(coinId: "bitcoin"))
        XCTAssertTrue(sut.isWatched(coinId: "bitcoin"))
    }

    func test_toggle_removesWhenAlreadyWatched() async {
        let (sut, _, watchRepo) = makeSUT(initiallyWatched: ["bitcoin"])
        await sut.refreshWatchedIds()
        await sut.toggle(coinId: "bitcoin")
        XCTAssertFalse(try watchRepo.isWatched(coinId: "bitcoin"))
        XCTAssertFalse(sut.isWatched(coinId: "bitcoin"))
    }
}
```

- [ ] **Step 2: Run; confirm FAIL**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/AddToWatchlistViewModelTests`

- [ ] **Step 3: Create `AddToWatchlistViewModel.swift`**

```swift
import Foundation

@MainActor
final class AddToWatchlistViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty
    @Published private(set) var watchedIds: Set<String> = []

    private let searchCoins: SearchCoinsUseCase
    private let toggleWatchlist: ToggleWatchlistUseCase
    private let watchlistRepository: WatchlistRepository

    init(searchCoins: SearchCoinsUseCase,
         toggleWatchlist: ToggleWatchlistUseCase,
         watchlistRepository: WatchlistRepository) {
        self.searchCoins = searchCoins
        self.toggleWatchlist = toggleWatchlist
        self.watchlistRepository = watchlistRepository
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

    func refreshWatchedIds() async {
        do {
            let items = try watchlistRepository.items()
            watchedIds = Set(items.map(\.coinId))
        } catch {
            watchedIds = []
        }
    }

    func isWatched(coinId: String) -> Bool { watchedIds.contains(coinId) }

    func toggle(coinId: String) async {
        do {
            try toggleWatchlist(coinId: coinId)
            await refreshWatchedIds()
        } catch {
            // No state slot for inline errors here; ignored at the VM layer.
            // A future enhancement could expose a toast or `.error` field.
        }
    }
}
```

- [ ] **Step 4: Create `AddToWatchlistView.swift`**

```swift
import SwiftUI

struct AddToWatchlistView: View {
    @StateObject private var viewModel: AddToWatchlistViewModel
    let onDone: () -> Void

    init(container: AppContainer, onDone: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AddToWatchlistViewModel(
            searchCoins: container.makeSearchCoinsUseCase(),
            toggleWatchlist: container.makeToggleWatchlistUseCase(),
            watchlistRepository: container.watchlistRepository
        ))
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("watchlist.addCoin.title")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("watchlist.search.prompt"))
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone() }
                    }
                }
                .task { await viewModel.refreshWatchedIds() }
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
                titleKey: "watchlist.add.empty.title",
                messageKey: "watchlist.add.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }
        case .loaded(let coins):
            List(coins) { coin in
                Button {
                    Task { await viewModel.toggle(coinId: coin.id) }
                } label: {
                    AddToWatchlistRow(coin: coin, isWatched: viewModel.isWatched(coinId: coin.id))
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}

private struct AddToWatchlistRow: View {
    let coin: Coin
    let isWatched: Bool

    var body: some View {
        HStack(spacing: 12) {
            coinImage
            VStack(alignment: .leading) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isWatched ? "star.fill" : "star")
                .foregroundStyle(isWatched ? Theme.accent : .secondary)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var coinImage: some View {
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
    }
}
```

- [ ] **Step 5: Re-wire `WatchlistView` to present the sheet**

Replace the `body` of `WatchlistView` (only the body — keep the rest unchanged) with:
```swift
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("watchlist.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.load() }
                .sheet(isPresented: $isShowingAddSheet) {
                    AddToWatchlistView(container: container) {
                        isShowingAddSheet = false
                        Task { await viewModel.load() }
                    }
                }
        }
    }
```

- [ ] **Step 6: Add L10n keys for AddToWatchlist**

Add inside `"strings"`:
```json
    "watchlist.addCoin.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Add to watchlist" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "İzlemeye ekle" } }
      }
    },
    "watchlist.add.empty.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Search to add a coin" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Coin eklemek için ara" } }
      }
    },
    "watchlist.add.empty.message" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Type a coin name or symbol and press Search." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Coin adı veya sembolü yazıp Ara'ya bas." } }
      }
    }
```

- [ ] **Step 7: Run targeted + full suite**

```
xcodegen generate
xcodebuild ... test -only-testing:CryptoPortfolioTests/AddToWatchlistViewModelTests
xcodebuild ... test
```
Expected: targeted 6/6; full suite **115 tests** (109 prior + 6 new), 0 failures.

- [ ] **Step 8: Commit**

```bash
git add CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistViewModel.swift CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistView.swift CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift CryptoPortfolio/Resources/Localizable.xcstrings CryptoPortfolioTests/Watchlist/Presentation/AddToWatchlistViewModelTests.swift
git commit -m "feat: add AddToWatchlistView with star-toggle search rows"
```

---

### Task 9: Wire Watchlist tab in `RootView` + simulator launch + screenshot

**Files:**
- Modify: `CryptoPortfolio/App/RootView.swift`
- Create: `docs/screenshots/phase4-watchlist-empty.png` (best-effort)

- [ ] **Step 1: Replace the ENTIRE contents of `CryptoPortfolio/App/RootView.swift`**

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

            PlaceholderTab(titleKey: "tab.alerts", systemImage: "bell.fill")
                .tabItem { Label("tab.alerts", systemImage: "bell.fill") }
        }
    }
}

private struct PlaceholderTab: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(titleKey)
                .font(.title2.bold())
            Text("common.comingSoon")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 2: Build + full suite**

```
xcodegen generate
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **` AND `** TEST SUCCEEDED **` with 115 tests, 0 failures.

- [ ] **Step 3: Launch simulator + capture Watchlist empty-state screenshot (best-effort)**

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
# Tap the Watchlist tab. Tab bar bottom area; for iPhone 17 (1206x2622) the middle tab is around (603, 2480).
xcrun simctl io booted tap 603 2480 2>/dev/null || true
sleep 1
xcrun simctl io booted screenshot docs/screenshots/phase4-watchlist-empty.png
file docs/screenshots/phase4-watchlist-empty.png
```
If `simctl io tap` is unsupported or hits the wrong area, the captured PNG may be the Portfolio launch screen — still acceptable evidence the app launched cleanly. Do NOT fail the task on tap precision.

- [ ] **Step 4: Commit**

```bash
git add CryptoPortfolio/App/RootView.swift docs/screenshots/
git status
git commit -m "feat: wire WatchlistView into the Watchlist tab; add phase4 screenshot"
```
Verify with `git status` between `add` and `commit` that `build/`, `CryptoPortfolio.xcodeproj`, and `Config/Secrets.xcconfig` are NOT staged. If any are, unstage and STOP.

---

## Self-Review

**1. Spec coverage (§5 layers, §6 data, §7 use cases, §8 Watchlist):**
- `WatchItem` domain entity → Task 1 ✅
- `WatchlistRepository` protocol → Task 1 ✅
- `CDWatchItem` Core Data model + impl → Task 2 ✅
- `GetWatchlistUseCase` + `ToggleWatchlistUseCase` (per spec §7) → Task 3 ✅
- Watchlist tab UI: searchable coin list + star-toggle add/remove + live price + 24h change + tap → CoinDetail → Tasks 7, 8, 9 ✅
- L10n (tr/en) for new strings → Tasks 7, 8 ✅

Structural debt addressed (per the Phase 3 deferred list):
- `userFacingMessage` → `APIError` extension (drops cross-VM coupling) → Task 4 ✅
- Feature views take `container: AppContainer` (RootView simplifies; NavigationLink factory chain removed) → Task 5 ✅

Deliberately deferred (NOT in Phase 4):
- CoinDetail "Add to watchlist" quick action → Phase 7 polish (CoinDetailViewModel would need ToggleWatchlistUseCase + watched state).
- Alerts (Phase 5) — still placeholder tab.
- Auto-poll refresh — Phase 7.
- `ViewState.error` localization (still English literals) — Phase 7 L10n pass.

**2. Placeholder scan:** No "TBD"/"TODO"/"add validation"-style placeholders. Every code step has complete code; every command has an expected output and a test count progression. The Task 9 screenshot step is genuinely best-effort and clearly marked.

**3. Type consistency:**
- `WatchItem(coinId:addedAt:)` (default addedAt = Date()) used in Tasks 1, 3, 8 — consistent.
- `WatchlistRepository` protocol methods identical across protocol (Task 1), impl (Task 2), `MockWatchlistRepository` (Task 3), `ToggleWatchlistUseCase` (Task 3), `GetWatchlistUseCase` (Task 3), `WatchlistViewModel` (Task 6), `AddToWatchlistViewModel` (Task 8).
- `ToggleWatchlistUseCase(watchlistRepository:)` + `GetWatchlistUseCase(watchlistRepository:coinRepository:)` consistent across Tasks 3, 6, 8.
- `AppContainer.makeGetWatchlistUseCase()` / `makeToggleWatchlistUseCase()` / `watchlistRepository` (the lazy property is accessed publicly by `AddToWatchlistViewModel`) used identically in Tasks 3, 6, 8.
- `error.userFacingMessage` is the single error-mapping form across `PortfolioViewModel`, `AddCoinViewModel`, `CoinDetailViewModel`, `WatchlistViewModel`, `AddToWatchlistViewModel` after Task 4.
- Container-init signatures unified: `PortfolioView(container:currency:)`, `AddCoinView(container:onDone:)`, `CoinDetailView(coinId:coinName:currency:container:)`, `WatchlistView(container:currency:)`, `AddToWatchlistView(container:onDone:)` — all consistent.
- `CDWatchItem` attributes (`coinId`, `addedAt`) match the model and the impl's reads/writes.
- Test count progression: 91 (start) → 93 (T1) → 99 (T2) → 104 (T3) → 104 (T4) → 104 (T5) → 109 (T6) → 109 (T7) → 115 (T8) → 115 (T9).

Required L10n keys used → present:
- Existing pre-Phase-4: `tab.portfolio`, `tab.watchlist`, `tab.alerts`, `common.comingSoon`, `common.retry`, `common.cancel`, `portfolio.*`, `addCoin.*`, `priceRange.*`, `coinDetail.*`.
- Added Task 7: `watchlist.title`, `watchlist.empty.title`, `watchlist.empty.message`, `watchlist.addCoin.accessibility`, `watchlist.unwatch`, `watchlist.search.prompt`.
- Added Task 8: `watchlist.addCoin.title`, `watchlist.add.empty.title`, `watchlist.add.empty.message`.

No issues found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-01-crypto-portfolio-ios-phase4-watchlist.md`.
