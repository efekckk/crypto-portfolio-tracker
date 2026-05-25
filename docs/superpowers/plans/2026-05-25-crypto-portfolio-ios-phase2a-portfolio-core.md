# Crypto Portfolio Tracker — Faz 2a: Portfolio Core (Data + Domain) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the fully unit-tested business core for the Portfolio feature: CoinGecko DTOs/mappers, coin + portfolio repositories (Core Data backed), and use cases (search, add-with-weighted-average, remove, and the profit/loss summary). No UI in this plan — that is Phase 2b.

**Architecture:** Clean Architecture continues. Domain stays pure Swift (entities, repository protocols, use cases). Data layer adds CoinGecko DTOs + mappers + repository implementations over the existing `HTTPClient` and `CoreDataStack`. P/L math lives in a use case, never in repositories or (future) view models. Monetary values stay `Double` (deliberate: display-oriented tracker, CoinGecko returns doubles, Swift Charts plots Double; precision at display scale is fine — revisit only if a real accounting ledger is added).

**Tech Stack:** Swift 5 mode, Swift Concurrency (async/await), Core Data, XCTest. No third-party deps.

Reference spec: `docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` (§6 Data, §7 Domain). Builds on Phase 1 (merged to `main`).

## Existing Phase 1 types this plan depends on (already in the codebase)
- `Coin(id:symbol:name:imageURL:currentPrice:priceChangePercentage24h:)` — `Domain/Entities/Coin.swift`
- `Holding(coinId:amount:averageBuyPrice:dateAdded:)` — `Domain/Entities/Holding.swift`
- `protocol HTTPClient { func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T }` — `Core/Network/HTTPClient.swift`
- `Endpoint(path:queryItems:)` — `Core/Network/Endpoint.swift`
- `APIError` (enum, Equatable) — `Core/Network/APIError.swift`
- `CoreDataStack(inMemory:)` with `viewContext` / `newBackgroundContext()`; model `CryptoPortfolio.xcdatamodeld` currently has one entity `CDCachedCoin` — `Core/Persistence/`
- `AppContainer` (final class) with `httpClient`, `rateLimiter`, `coreDataStack`, `analytics`, `crashReporter`; init `init(httpClient: HTTPClient? = nil, rateLimiter:..., coreDataStack:..., ...)` — `Core/DI/AppContainer.swift`
- Test helpers: `MockURLProtocol` (`CryptoPortfolioTests/Support/MockURLProtocol.swift`).

Build/test commands (simulator "iPhone 17"); the `.xcodeproj` is generated, so regenerate after adding files:
```
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test
```
To run one test class: append `-only-testing:CryptoPortfolioTests/<ClassName>`.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `CryptoPortfolio/Domain/Entities/Currency.swift` | Display/quote currency (usd, try) + code/symbol |
| `CryptoPortfolio/Features/Portfolio/Data/DTO/CoinMarketDTO.swift` | Decodes `/coins/markets` rows |
| `CryptoPortfolio/Features/Portfolio/Data/DTO/CoinSearchDTO.swift` | Decodes `/search` response |
| `CryptoPortfolio/Features/Portfolio/Data/Mapping/CoinMapper.swift` | DTO → `Coin` |
| `CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift` | Builds `Endpoint`s for markets/search |
| `CryptoPortfolio/Domain/Repositories/CoinRepository.swift` | Protocol: search + markets (shared across features) |
| `CryptoPortfolio/Features/Portfolio/Data/CoinRepositoryImpl.swift` | `CoinRepository` over `HTTPClient` |
| `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/.../contents` | Add `CDHolding` entity (modify) |
| `CryptoPortfolio/Features/Portfolio/Domain/PortfolioRepository.swift` | Protocol: holdings CRUD |
| `CryptoPortfolio/Features/Portfolio/Data/PortfolioRepositoryImpl.swift` | `PortfolioRepository` over Core Data |
| `CryptoPortfolio/Features/Portfolio/Domain/PortfolioSummary.swift` | `PortfolioSummary` + `HoldingValuation` |
| `CryptoPortfolio/Features/Portfolio/Domain/UseCases/SearchCoinsUseCase.swift` | Search coins |
| `CryptoPortfolio/Features/Portfolio/Domain/UseCases/AddHoldingUseCase.swift` | Add/merge holding (weighted avg) |
| `CryptoPortfolio/Features/Portfolio/Domain/UseCases/RemoveHoldingUseCase.swift` | Remove holding |
| `CryptoPortfolio/Features/Portfolio/Domain/UseCases/GetPortfolioSummaryUseCase.swift` | P/L summary (the math) |
| `CryptoPortfolio/Core/DI/AppContainer.swift` | Add repository factories (modify) |
| `CryptoPortfolioTests/**` | Mirror tests |

---

### Task 1: `Currency` entity

**Files:**
- Create: `CryptoPortfolio/Domain/Entities/Currency.swift`
- Test: `CryptoPortfolioTests/Domain/CurrencyTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Domain/CurrencyTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class CurrencyTests: XCTestCase {
    func test_codeMatchesCoinGeckoParameter() {
        XCTAssertEqual(Currency.usd.code, "usd")
        XCTAssertEqual(Currency.tryLira.code, "try")
    }

    func test_symbol() {
        XCTAssertEqual(Currency.usd.symbol, "$")
        XCTAssertEqual(Currency.tryLira.symbol, "₺")
    }

    func test_defaultIsUSD() {
        XCTAssertEqual(Currency.default, .usd)
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/CurrencyTests`
Expected: FAIL to compile — `cannot find 'Currency' in scope`.

- [ ] **Step 3: Create the implementation**

Create `CryptoPortfolio/Domain/Entities/Currency.swift`:
```swift
import Foundation

/// Quote/display currency. `code` is the CoinGecko `vs_currency` parameter.
enum Currency: String, CaseIterable, Identifiable {
    case usd
    case tryLira = "try"   // `try` is a Swift keyword; raw value is the API code

    static let `default`: Currency = .usd

    var id: String { rawValue }
    var code: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .tryLira: return "₺"
        }
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Domain/Entities/Currency.swift CryptoPortfolioTests/Domain/CurrencyTests.swift
git commit -m "feat: add Currency entity (usd/try) for portfolio valuation"
```

---

### Task 2: CoinGecko DTOs

**Files:**
- Create: `CryptoPortfolio/Features/Portfolio/Data/DTO/CoinMarketDTO.swift`
- Create: `CryptoPortfolio/Features/Portfolio/Data/DTO/CoinSearchDTO.swift`
- Test: `CryptoPortfolioTests/Portfolio/Data/CoinDTOTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Portfolio/Data/CoinDTOTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class CoinDTOTests: XCTestCase {
    func test_decodesCoinMarketDTOFromCoinGeckoJSON() throws {
        let json = """
        [{
          "id": "bitcoin",
          "symbol": "btc",
          "name": "Bitcoin",
          "image": "https://example.com/btc.png",
          "current_price": 50000.5,
          "price_change_percentage_24h": 2.34
        }]
        """.data(using: .utf8)!

        let dtos = try JSONDecoder().decode([CoinMarketDTO].self, from: json)

        XCTAssertEqual(dtos.count, 1)
        XCTAssertEqual(dtos[0].id, "bitcoin")
        XCTAssertEqual(dtos[0].symbol, "btc")
        XCTAssertEqual(dtos[0].name, "Bitcoin")
        XCTAssertEqual(dtos[0].image, "https://example.com/btc.png")
        XCTAssertEqual(dtos[0].currentPrice, 50000.5)
        XCTAssertEqual(dtos[0].priceChangePercentage24h, 2.34)
    }

    func test_decodesCoinMarketDTOWithMissingOptionalFields() throws {
        let json = """
        [{ "id": "x", "symbol": "x", "name": "X" }]
        """.data(using: .utf8)!

        let dtos = try JSONDecoder().decode([CoinMarketDTO].self, from: json)

        XCTAssertNil(dtos[0].image)
        XCTAssertNil(dtos[0].currentPrice)
        XCTAssertNil(dtos[0].priceChangePercentage24h)
    }

    func test_decodesSearchResponse() throws {
        let json = """
        {
          "coins": [
            { "id": "ethereum", "name": "Ethereum", "symbol": "ETH",
              "thumb": "https://example.com/eth-thumb.png",
              "large": "https://example.com/eth-large.png" }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CoinSearchResponseDTO.self, from: json)

        XCTAssertEqual(response.coins.count, 1)
        XCTAssertEqual(response.coins[0].id, "ethereum")
        XCTAssertEqual(response.coins[0].symbol, "ETH")
        XCTAssertEqual(response.coins[0].large, "https://example.com/eth-large.png")
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/CoinDTOTests`
Expected: FAIL to compile — `cannot find 'CoinMarketDTO' / 'CoinSearchResponseDTO' in scope`.

- [ ] **Step 3: Create the DTOs**

Create `CryptoPortfolio/Features/Portfolio/Data/DTO/CoinMarketDTO.swift`:
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

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
    }
}
```

Create `CryptoPortfolio/Features/Portfolio/Data/DTO/CoinSearchDTO.swift`:
```swift
import Foundation

/// CoinGecko `/search` response (only the `coins` array is used).
struct CoinSearchResponseDTO: Decodable {
    let coins: [CoinSearchItemDTO]
}

struct CoinSearchItemDTO: Decodable {
    let id: String
    let name: String
    let symbol: String
    let thumb: String?
    let large: String?
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Data/DTO CryptoPortfolioTests/Portfolio/Data/CoinDTOTests.swift
git commit -m "feat: add CoinGecko market and search DTOs"
```

---

### Task 3: `CoinMapper` (DTO → Coin)

**Files:**
- Create: `CryptoPortfolio/Features/Portfolio/Data/Mapping/CoinMapper.swift`
- Test: `CryptoPortfolioTests/Portfolio/Data/CoinMapperTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Portfolio/Data/CoinMapperTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class CoinMapperTests: XCTestCase {
    func test_mapsMarketDTOToCoin() {
        let dto = CoinMarketDTO(
            id: "bitcoin", symbol: "btc", name: "Bitcoin",
            image: "https://example.com/btc.png",
            currentPrice: 50000, priceChangePercentage24h: 2.5
        )

        let coin = CoinMapper.map(dto)

        XCTAssertEqual(coin.id, "bitcoin")
        XCTAssertEqual(coin.symbol, "btc")
        XCTAssertEqual(coin.name, "Bitcoin")
        XCTAssertEqual(coin.imageURL, URL(string: "https://example.com/btc.png"))
        XCTAssertEqual(coin.currentPrice, 50000)
        XCTAssertEqual(coin.priceChangePercentage24h, 2.5)
    }

    func test_mapsMarketDTOWithNilsToZeroAndNilURL() {
        let dto = CoinMarketDTO(id: "x", symbol: "x", name: "X",
                                image: nil, currentPrice: nil, priceChangePercentage24h: nil)

        let coin = CoinMapper.map(dto)

        XCTAssertNil(coin.imageURL)
        XCTAssertEqual(coin.currentPrice, 0)
        XCTAssertEqual(coin.priceChangePercentage24h, 0)
    }

    func test_mapsSearchItemPreferringLargeImage_andZeroPrice() {
        let dto = CoinSearchItemDTO(id: "ethereum", name: "Ethereum", symbol: "ETH",
                                    thumb: "https://example.com/thumb.png",
                                    large: "https://example.com/large.png")

        let coin = CoinMapper.map(dto)

        XCTAssertEqual(coin.id, "ethereum")
        XCTAssertEqual(coin.imageURL, URL(string: "https://example.com/large.png"))
        XCTAssertEqual(coin.currentPrice, 0, "Search results carry no price")
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/CoinMapperTests`
Expected: FAIL to compile — `cannot find 'CoinMapper' in scope`.

- [ ] **Step 3: Create the mapper**

Create `CryptoPortfolio/Features/Portfolio/Data/Mapping/CoinMapper.swift`:
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
            priceChangePercentage24h: dto.priceChangePercentage24h ?? 0
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

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Data/Mapping CryptoPortfolioTests/Portfolio/Data/CoinMapperTests.swift
git commit -m "feat: add CoinMapper from CoinGecko DTOs to Coin"
```

---

### Task 4: `CoinGeckoEndpoints`

**Files:**
- Create: `CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift`
- Test: `CryptoPortfolioTests/Network/CoinGeckoEndpointsTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Network/CoinGeckoEndpointsTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class CoinGeckoEndpointsTests: XCTestCase {
    func test_marketsEndpoint() {
        let endpoint = CoinGeckoEndpoints.markets(ids: ["bitcoin", "ethereum"], vsCurrency: "usd")

        XCTAssertEqual(endpoint.path, "coins/markets")
        let items = Dictionary(uniqueKeysWithValues: endpoint.queryItems.map { ($0.name, $0.value) })
        XCTAssertEqual(items["vs_currency"], "usd")
        XCTAssertEqual(items["ids"], "bitcoin,ethereum")
        XCTAssertEqual(items["price_change_percentage"], "24h")
    }

    func test_searchEndpoint() {
        let endpoint = CoinGeckoEndpoints.search(query: "bit")

        XCTAssertEqual(endpoint.path, "search")
        XCTAssertEqual(endpoint.queryItems.first(where: { $0.name == "query" })?.value, "bit")
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/CoinGeckoEndpointsTests`
Expected: FAIL to compile — `cannot find 'CoinGeckoEndpoints' in scope`.

- [ ] **Step 3: Create the endpoints factory**

Create `CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift`:
```swift
import Foundation

/// Builds `Endpoint`s for the CoinGecko REST API.
enum CoinGeckoEndpoints {
    static func markets(ids: [String], vsCurrency: String) -> Endpoint {
        Endpoint(path: "coins/markets", queryItems: [
            URLQueryItem(name: "vs_currency", value: vsCurrency),
            URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
            URLQueryItem(name: "price_change_percentage", value: "24h")
        ])
    }

    static func search(query: String) -> Endpoint {
        Endpoint(path: "search", queryItems: [
            URLQueryItem(name: "query", value: query)
        ])
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Core/Network/CoinGeckoEndpoints.swift CryptoPortfolioTests/Network/CoinGeckoEndpointsTests.swift
git commit -m "feat: add CoinGecko endpoint builders for markets and search"
```

---

### Task 5: `CoinRepository` protocol + `CoinRepositoryImpl`

**Files:**
- Create: `CryptoPortfolio/Domain/Repositories/CoinRepository.swift`
- Create: `CryptoPortfolio/Features/Portfolio/Data/CoinRepositoryImpl.swift`
- Test: `CryptoPortfolioTests/Portfolio/Data/CoinRepositoryImplTests.swift`

Note: this repository is network-only in this phase. Offline caching via the existing
`CDCachedCoin` entity is a later enhancement (tracked separately); do not add it here.

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Portfolio/Data/CoinRepositoryImplTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

/// Records the endpoints sent and returns a canned Decodable per call.
private final class StubHTTPClient: HTTPClient {
    var responses: [Any] = []
    private(set) var sentEndpoints: [Endpoint] = []
    var errorToThrow: Error?

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        sentEndpoints.append(endpoint)
        if let errorToThrow { throw errorToThrow }
        return responses.removeFirst() as! T
    }
}

final class CoinRepositoryImplTests: XCTestCase {
    func test_searchCoins_mapsSearchResultsToCoins() async throws {
        let stub = StubHTTPClient()
        stub.responses = [
            CoinSearchResponseDTO(coins: [
                CoinSearchItemDTO(id: "bitcoin", name: "Bitcoin", symbol: "btc", thumb: nil, large: nil)
            ])
        ]
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.searchCoins(query: "bit")

        XCTAssertEqual(coins.map(\.id), ["bitcoin"])
        XCTAssertEqual(stub.sentEndpoints.first?.path, "search")
    }

    func test_searchCoins_returnsEmptyForBlankQueryWithoutCallingNetwork() async throws {
        let stub = StubHTTPClient()
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.searchCoins(query: "   ")

        XCTAssertTrue(coins.isEmpty)
        XCTAssertTrue(stub.sentEndpoints.isEmpty, "Blank query must not hit the network")
    }

    func test_markets_mapsMarketDTOsToCoins() async throws {
        let stub = StubHTTPClient()
        stub.responses = [
            [CoinMarketDTO(id: "bitcoin", symbol: "btc", name: "Bitcoin",
                           image: nil, currentPrice: 50000, priceChangePercentage24h: 1.0)]
        ]
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.markets(ids: ["bitcoin"], currency: .usd)

        XCTAssertEqual(coins.map(\.currentPrice), [50000])
        XCTAssertEqual(stub.sentEndpoints.first?.path, "coins/markets")
    }

    func test_markets_returnsEmptyForEmptyIdsWithoutCallingNetwork() async throws {
        let stub = StubHTTPClient()
        let sut = CoinRepositoryImpl(httpClient: stub)

        let coins = try await sut.markets(ids: [], currency: .usd)

        XCTAssertTrue(coins.isEmpty)
        XCTAssertTrue(stub.sentEndpoints.isEmpty)
    }

    func test_markets_propagatesNetworkError() async {
        let stub = StubHTTPClient()
        stub.errorToThrow = APIError.rateLimited
        let sut = CoinRepositoryImpl(httpClient: stub)

        do {
            _ = try await sut.markets(ids: ["bitcoin"], currency: .usd)
            XCTFail("Expected to throw")
        } catch let error as APIError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/CoinRepositoryImplTests`
Expected: FAIL to compile — `cannot find 'CoinRepository' / 'CoinRepositoryImpl' in scope`.

- [ ] **Step 3: Create the protocol and implementation**

Create `CryptoPortfolio/Domain/Repositories/CoinRepository.swift`:
```swift
import Foundation

/// Read access to coin market data. Shared across Portfolio/Watchlist/CoinDetail.
protocol CoinRepository {
    func searchCoins(query: String) async throws -> [Coin]
    func markets(ids: [String], currency: Currency) async throws -> [Coin]
}
```

Create `CryptoPortfolio/Features/Portfolio/Data/CoinRepositoryImpl.swift`:
```swift
import Foundation

/// CoinGecko-backed `CoinRepository`.
final class CoinRepositoryImpl: CoinRepository {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func searchCoins(query: String) async throws -> [Coin] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: CoinSearchResponseDTO = try await httpClient.send(
            CoinGeckoEndpoints.search(query: trimmed), as: CoinSearchResponseDTO.self
        )
        return response.coins.map(CoinMapper.map)
    }

    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        guard !ids.isEmpty else { return [] }
        let dtos: [CoinMarketDTO] = try await httpClient.send(
            CoinGeckoEndpoints.markets(ids: ids, vsCurrency: currency.code), as: [CoinMarketDTO].self
        )
        return dtos.map(CoinMapper.map)
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Domain/Repositories CryptoPortfolio/Features/Portfolio/Data/CoinRepositoryImpl.swift CryptoPortfolioTests/Portfolio/Data/CoinRepositoryImplTests.swift
git commit -m "feat: add CoinRepository protocol and CoinGecko-backed implementation"
```

---

### Task 6: `CDHolding` model + `PortfolioRepository` + `PortfolioRepositoryImpl`

**Files:**
- Modify: `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents`
- Create: `CryptoPortfolio/Features/Portfolio/Domain/PortfolioRepository.swift`
- Create: `CryptoPortfolio/Features/Portfolio/Data/PortfolioRepositoryImpl.swift`
- Test: `CryptoPortfolioTests/Portfolio/Data/PortfolioRepositoryImplTests.swift`

- [ ] **Step 1: Add the `CDHolding` entity to the Core Data model**

Replace the ENTIRE contents of `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents` with (adds `CDHolding`, keeps `CDCachedCoin`):
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
</model>
```

- [ ] **Step 2: Write the failing test**

Create `CryptoPortfolioTests/Portfolio/Data/PortfolioRepositoryImplTests.swift`:
```swift
import XCTest
import CoreData
@testable import CryptoPortfolio

final class PortfolioRepositoryImplTests: XCTestCase {
    private func makeSUT() -> PortfolioRepositoryImpl {
        PortfolioRepositoryImpl(stack: CoreDataStack(inMemory: true))
    }

    func test_holdings_startsEmpty() throws {
        let sut = makeSUT()
        XCTAssertTrue(try sut.holdings().isEmpty)
    }

    func test_save_thenHoldings_returnsSavedHolding() throws {
        let sut = makeSUT()
        try sut.save(Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000,
                             dateAdded: Date(timeIntervalSince1970: 1000)))

        let holdings = try sut.holdings()

        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings.first?.coinId, "bitcoin")
        XCTAssertEqual(holdings.first?.amount, 2)
        XCTAssertEqual(holdings.first?.averageBuyPrice, 40000)
    }

    func test_save_withSameCoinId_updatesInsteadOfDuplicating() throws {
        let sut = makeSUT()
        try sut.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 30000))
        try sut.save(Holding(coinId: "bitcoin", amount: 3, averageBuyPrice: 45000))

        let holdings = try sut.holdings()

        XCTAssertEqual(holdings.count, 1, "Same coinId must update, not duplicate")
        XCTAssertEqual(holdings.first?.amount, 3)
        XCTAssertEqual(holdings.first?.averageBuyPrice, 45000)
    }

    func test_holding_returnsNilWhenAbsent_andValueWhenPresent() throws {
        let sut = makeSUT()
        XCTAssertNil(try sut.holding(coinId: "bitcoin"))

        try sut.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100))

        XCTAssertEqual(try sut.holding(coinId: "bitcoin")?.amount, 1)
    }

    func test_remove_deletesHolding() throws {
        let sut = makeSUT()
        try sut.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100))
        try sut.save(Holding(coinId: "ethereum", amount: 5, averageBuyPrice: 2000))

        try sut.remove(coinId: "bitcoin")

        let holdings = try sut.holdings()
        XCTAssertEqual(holdings.map(\.coinId), ["ethereum"])
    }
}
```

- [ ] **Step 3: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/PortfolioRepositoryImplTests`
Expected: FAIL to compile — `cannot find 'PortfolioRepository' / 'PortfolioRepositoryImpl' in scope`. (`CDHolding` should compile from the model added in Step 1.)

- [ ] **Step 4: Create the protocol and implementation**

Create `CryptoPortfolio/Features/Portfolio/Domain/PortfolioRepository.swift`:
```swift
import Foundation

/// Persistence for the user's holdings (one per coin id).
protocol PortfolioRepository {
    func holdings() throws -> [Holding]
    func holding(coinId: String) throws -> Holding?
    func save(_ holding: Holding) throws   // upsert by coinId
    func remove(coinId: String) throws
}
```

Create `CryptoPortfolio/Features/Portfolio/Data/PortfolioRepositoryImpl.swift`:
```swift
import CoreData

/// Core Data-backed `PortfolioRepository`. Upserts by `coinId`.
final class PortfolioRepositoryImpl: PortfolioRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    private var context: NSManagedObjectContext { stack.viewContext }

    func holdings() throws -> [Holding] {
        let request = NSFetchRequest<CDHolding>(entityName: "CDHolding")
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: true)]
        return try context.fetch(request).map(Self.toDomain)
    }

    func holding(coinId: String) throws -> Holding? {
        try fetchEntity(coinId: coinId).map(Self.toDomain)
    }

    func save(_ holding: Holding) throws {
        let entity = try fetchEntity(coinId: holding.coinId) ?? CDHolding(context: context)
        entity.coinId = holding.coinId
        entity.amount = holding.amount
        entity.averageBuyPrice = holding.averageBuyPrice
        entity.dateAdded = holding.dateAdded
        try context.save()
    }

    func remove(coinId: String) throws {
        guard let entity = try fetchEntity(coinId: coinId) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - Helpers

    private func fetchEntity(coinId: String) throws -> CDHolding? {
        let request = NSFetchRequest<CDHolding>(entityName: "CDHolding")
        request.predicate = NSPredicate(format: "coinId == %@", coinId)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func toDomain(_ entity: CDHolding) -> Holding {
        Holding(
            coinId: entity.coinId ?? "",
            amount: entity.amount,
            averageBuyPrice: entity.averageBuyPrice,
            dateAdded: entity.dateAdded ?? Date()
        )
    }
}
```

- [ ] **Step 5: Run the test, verify it passes**

Run the same command as Step 3. Expected: `** TEST SUCCEEDED **`, 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Core/Persistence CryptoPortfolio/Features/Portfolio/Domain/PortfolioRepository.swift CryptoPortfolio/Features/Portfolio/Data/PortfolioRepositoryImpl.swift CryptoPortfolioTests/Portfolio/Data/PortfolioRepositoryImplTests.swift
git commit -m "feat: add CDHolding model and Core Data PortfolioRepository"
```

---

### Task 7: `PortfolioSummary` + `HoldingValuation` entities

**Files:**
- Create: `CryptoPortfolio/Features/Portfolio/Domain/PortfolioSummary.swift`
- Test: `CryptoPortfolioTests/Portfolio/Domain/HoldingValuationTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Portfolio/Domain/HoldingValuationTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class HoldingValuationTests: XCTestCase {
    func test_profitLossComputedFromValueAndCost() {
        let valuation = HoldingValuation(
            holding: Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000),
            coin: nil,
            currentValue: 100000,
            cost: 80000
        )

        XCTAssertEqual(valuation.absolutePnL, 20000)
        XCTAssertEqual(valuation.percentPnL, 25)
    }

    func test_percentPnLIsZeroWhenCostIsZero() {
        let valuation = HoldingValuation(
            holding: Holding(coinId: "x", amount: 1, averageBuyPrice: 0),
            coin: nil,
            currentValue: 50,
            cost: 0
        )

        XCTAssertEqual(valuation.percentPnL, 0)
    }

    func test_emptySummaryHasZeros() {
        XCTAssertEqual(PortfolioSummary.empty.totalValue, 0)
        XCTAssertEqual(PortfolioSummary.empty.absolutePnL, 0)
        XCTAssertTrue(PortfolioSummary.empty.items.isEmpty)
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/HoldingValuationTests`
Expected: FAIL to compile — `cannot find 'HoldingValuation' / 'PortfolioSummary' in scope`.

- [ ] **Step 3: Create the entities**

Create `CryptoPortfolio/Features/Portfolio/Domain/PortfolioSummary.swift`:
```swift
import Foundation

/// A single holding valued at current price.
struct HoldingValuation: Identifiable, Equatable {
    var id: String { holding.coinId }
    let holding: Holding
    let coin: Coin?          // current market snapshot, if available
    let currentValue: Double // amount * current price
    let cost: Double         // amount * average buy price

    var absolutePnL: Double { currentValue - cost }
    var percentPnL: Double { cost > 0 ? (absolutePnL / cost) * 100 : 0 }
}

/// Aggregate valuation of the whole portfolio.
struct PortfolioSummary: Equatable {
    let totalValue: Double
    let totalCost: Double
    let absolutePnL: Double
    let percentPnL: Double
    let items: [HoldingValuation]

    static let empty = PortfolioSummary(
        totalValue: 0, totalCost: 0, absolutePnL: 0, percentPnL: 0, items: []
    )
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Domain/PortfolioSummary.swift CryptoPortfolioTests/Portfolio/Domain/HoldingValuationTests.swift
git commit -m "feat: add PortfolioSummary and HoldingValuation entities"
```

---

### Task 8: Search / Add / Remove use cases

**Files:**
- Create: `CryptoPortfolio/Features/Portfolio/Domain/UseCases/SearchCoinsUseCase.swift`
- Create: `CryptoPortfolio/Features/Portfolio/Domain/UseCases/AddHoldingUseCase.swift`
- Create: `CryptoPortfolio/Features/Portfolio/Domain/UseCases/RemoveHoldingUseCase.swift`
- Test: `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

// MARK: - Mocks

final class MockCoinRepository: CoinRepository {
    var searchResult: [Coin] = []
    var marketsResult: [Coin] = []
    private(set) var lastSearchQuery: String?

    func searchCoins(query: String) async throws -> [Coin] {
        lastSearchQuery = query
        return searchResult
    }
    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        marketsResult
    }
}

final class MockPortfolioRepository: PortfolioRepository {
    var storage: [String: Holding] = [:]

    func holdings() throws -> [Holding] {
        storage.values.sorted { $0.coinId < $1.coinId }
    }
    func holding(coinId: String) throws -> Holding? { storage[coinId] }
    func save(_ holding: Holding) throws { storage[holding.coinId] = holding }
    func remove(coinId: String) throws { storage[coinId] = nil }
}

final class PortfolioUseCasesTests: XCTestCase {
    func test_searchCoins_delegatesToRepository() async throws {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")]
        let sut = SearchCoinsUseCase(coinRepository: coinRepo)

        let result = try await sut("bit")

        XCTAssertEqual(coinRepo.lastSearchQuery, "bit")
        XCTAssertEqual(result.map(\.id), ["bitcoin"])
    }

    func test_addHolding_createsNewHoldingWhenAbsent() throws {
        let repo = MockPortfolioRepository()
        let sut = AddHoldingUseCase(portfolioRepository: repo)

        try sut(coinId: "bitcoin", amount: 2, buyPrice: 40000)

        let saved = try repo.holding(coinId: "bitcoin")
        XCTAssertEqual(saved?.amount, 2)
        XCTAssertEqual(saved?.averageBuyPrice, 40000)
    }

    func test_addHolding_mergesWithWeightedAverageBuyPrice() throws {
        let repo = MockPortfolioRepository()
        try repo.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 30000))
        let sut = AddHoldingUseCase(portfolioRepository: repo)

        // Add 3 more units at 50000 => total 4 units, avg = (1*30000 + 3*50000)/4 = 45000
        try sut(coinId: "bitcoin", amount: 3, buyPrice: 50000)

        let saved = try repo.holding(coinId: "bitcoin")
        XCTAssertEqual(saved?.amount, 4)
        XCTAssertEqual(saved?.averageBuyPrice, 45000)
    }

    func test_addHolding_throwsOnNonPositiveAmount() {
        let repo = MockPortfolioRepository()
        let sut = AddHoldingUseCase(portfolioRepository: repo)

        XCTAssertThrowsError(try sut(coinId: "bitcoin", amount: 0, buyPrice: 100)) { error in
            XCTAssertEqual(error as? PortfolioError, .invalidAmount)
        }
    }

    func test_removeHolding_delegatesToRepository() throws {
        let repo = MockPortfolioRepository()
        try repo.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100))
        let sut = RemoveHoldingUseCase(portfolioRepository: repo)

        try sut(coinId: "bitcoin")

        XCTAssertNil(try repo.holding(coinId: "bitcoin"))
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/PortfolioUseCasesTests`
Expected: FAIL to compile — `cannot find 'SearchCoinsUseCase' / 'AddHoldingUseCase' / 'RemoveHoldingUseCase' / 'PortfolioError' in scope`.

- [ ] **Step 3: Create the use cases**

Create `CryptoPortfolio/Features/Portfolio/Domain/UseCases/SearchCoinsUseCase.swift`:
```swift
import Foundation

struct SearchCoinsUseCase {
    let coinRepository: CoinRepository

    func callAsFunction(_ query: String) async throws -> [Coin] {
        try await coinRepository.searchCoins(query: query)
    }
}
```

Create `CryptoPortfolio/Features/Portfolio/Domain/UseCases/AddHoldingUseCase.swift`:
```swift
import Foundation

enum PortfolioError: Error, Equatable {
    case invalidAmount
}

struct AddHoldingUseCase {
    let portfolioRepository: PortfolioRepository

    /// Adds `amount` units bought at `buyPrice`. If a holding for `coinId` already
    /// exists, merges into it and recomputes the weighted average buy price.
    func callAsFunction(coinId: String, amount: Double, buyPrice: Double) throws {
        guard amount > 0 else { throw PortfolioError.invalidAmount }

        let merged: Holding
        if let existing = try portfolioRepository.holding(coinId: coinId) {
            let totalAmount = existing.amount + amount
            let weightedAverage = totalAmount > 0
                ? (existing.amount * existing.averageBuyPrice + amount * buyPrice) / totalAmount
                : buyPrice
            merged = Holding(coinId: coinId, amount: totalAmount,
                             averageBuyPrice: weightedAverage, dateAdded: existing.dateAdded)
        } else {
            merged = Holding(coinId: coinId, amount: amount, averageBuyPrice: buyPrice)
        }
        try portfolioRepository.save(merged)
    }
}
```

Create `CryptoPortfolio/Features/Portfolio/Domain/UseCases/RemoveHoldingUseCase.swift`:
```swift
import Foundation

struct RemoveHoldingUseCase {
    let portfolioRepository: PortfolioRepository

    func callAsFunction(coinId: String) throws {
        try portfolioRepository.remove(coinId: coinId)
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Domain/UseCases/SearchCoinsUseCase.swift CryptoPortfolio/Features/Portfolio/Domain/UseCases/AddHoldingUseCase.swift CryptoPortfolio/Features/Portfolio/Domain/UseCases/RemoveHoldingUseCase.swift CryptoPortfolioTests/Portfolio/Domain/PortfolioUseCasesTests.swift
git commit -m "feat: add search/add(weighted-avg)/remove holding use cases"
```

---

### Task 9: `GetPortfolioSummaryUseCase` (P/L math)

**Files:**
- Create: `CryptoPortfolio/Features/Portfolio/Domain/UseCases/GetPortfolioSummaryUseCase.swift`
- Test: `CryptoPortfolioTests/Portfolio/Domain/GetPortfolioSummaryUseCaseTests.swift`

This task reuses `MockCoinRepository` and `MockPortfolioRepository` defined in Task 8's test file (`PortfolioUseCasesTests.swift`), which are in the same test target.

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/Portfolio/Domain/GetPortfolioSummaryUseCaseTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class GetPortfolioSummaryUseCaseTests: XCTestCase {
    private func makeSUT(holdings: [Holding], coins: [Coin])
        -> (GetPortfolioSummaryUseCase, MockPortfolioRepository, MockCoinRepository) {
        let portfolioRepo = MockPortfolioRepository()
        for h in holdings { try? portfolioRepo.save(h) }
        let coinRepo = MockCoinRepository()
        coinRepo.marketsResult = coins
        return (GetPortfolioSummaryUseCase(portfolioRepository: portfolioRepo, coinRepository: coinRepo),
                portfolioRepo, coinRepo)
    }

    func test_emptyPortfolio_returnsEmptySummary() async throws {
        let (sut, _, _) = makeSUT(holdings: [], coins: [])
        let summary = try await sut(currency: .usd)
        XCTAssertEqual(summary, .empty)
    }

    func test_singleHolding_inProfit() async throws {
        let (sut, _, _) = makeSUT(
            holdings: [Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000)],
            coins: [Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50000)]
        )

        let summary = try await sut(currency: .usd)

        // value = 2*50000 = 100000, cost = 2*40000 = 80000, pnl = 20000, pct = 25
        XCTAssertEqual(summary.totalValue, 100000)
        XCTAssertEqual(summary.totalCost, 80000)
        XCTAssertEqual(summary.absolutePnL, 20000)
        XCTAssertEqual(summary.percentPnL, 25)
        XCTAssertEqual(summary.items.count, 1)
        XCTAssertEqual(summary.items.first?.coin?.id, "bitcoin")
    }

    func test_multipleHoldings_aggregateValueAndPnL() async throws {
        let (sut, _, _) = makeSUT(
            holdings: [
                Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 50000),
                Holding(coinId: "ethereum", amount: 10, averageBuyPrice: 1000)
            ],
            coins: [
                Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 40000),
                Coin(id: "ethereum", symbol: "eth", name: "Ethereum", currentPrice: 2000)
            ]
        )

        let summary = try await sut(currency: .usd)

        // BTC: value 40000, cost 50000 (loss 10000). ETH: value 20000, cost 10000 (profit 10000).
        // total value = 60000, total cost = 60000, pnl = 0, pct = 0
        XCTAssertEqual(summary.totalValue, 60000)
        XCTAssertEqual(summary.totalCost, 60000)
        XCTAssertEqual(summary.absolutePnL, 0)
        XCTAssertEqual(summary.percentPnL, 0)
        XCTAssertEqual(summary.items.count, 2)
    }

    func test_holdingWithMissingPrice_valuedAtZero() async throws {
        let (sut, _, _) = makeSUT(
            holdings: [Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000)],
            coins: [] // markets returned nothing for this id
        )

        let summary = try await sut(currency: .usd)

        XCTAssertEqual(summary.totalValue, 0)
        XCTAssertEqual(summary.totalCost, 80000)
        XCTAssertEqual(summary.absolutePnL, -80000)
        XCTAssertEqual(summary.items.first?.coin, nil)
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/GetPortfolioSummaryUseCaseTests`
Expected: FAIL to compile — `cannot find 'GetPortfolioSummaryUseCase' in scope`.

- [ ] **Step 3: Create the use case**

Create `CryptoPortfolio/Features/Portfolio/Domain/UseCases/GetPortfolioSummaryUseCase.swift`:
```swift
import Foundation

/// Combines persisted holdings with current market prices to compute portfolio
/// value and profit/loss. All money math lives here.
struct GetPortfolioSummaryUseCase {
    let portfolioRepository: PortfolioRepository
    let coinRepository: CoinRepository

    func callAsFunction(currency: Currency) async throws -> PortfolioSummary {
        let holdings = try portfolioRepository.holdings()
        guard !holdings.isEmpty else { return .empty }

        let coins = try await coinRepository.markets(ids: holdings.map(\.coinId), currency: currency)
        let coinsById = Dictionary(coins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var items: [HoldingValuation] = []
        var totalValue = 0.0
        var totalCost = 0.0

        for holding in holdings {
            let coin = coinsById[holding.coinId]
            let price = coin?.currentPrice ?? 0
            let value = holding.amount * price
            let cost = holding.amount * holding.averageBuyPrice
            items.append(HoldingValuation(holding: holding, coin: coin, currentValue: value, cost: cost))
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

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Domain/UseCases/GetPortfolioSummaryUseCase.swift CryptoPortfolioTests/Portfolio/Domain/GetPortfolioSummaryUseCaseTests.swift
git commit -m "feat: add GetPortfolioSummaryUseCase with P/L math"
```

---

### Task 10: Wire repositories + use case factories into `AppContainer`

**Files:**
- Modify: `CryptoPortfolio/Core/DI/AppContainer.swift`
- Test: `CryptoPortfolioTests/DI/AppContainerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/DI/AppContainerTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class AppContainerTests: XCTestCase {
    private func makeSUT() -> AppContainer {
        AppContainer(coreDataStack: CoreDataStack(inMemory: true))
    }

    func test_buildsPortfolioUseCases() throws {
        let container = makeSUT()

        // Use cases are constructible and operate on the container's repositories.
        try container.makeAddHoldingUseCase()(coinId: "bitcoin", amount: 1, buyPrice: 100)
        let holdings = try container.portfolioRepository.holdings()

        XCTAssertEqual(holdings.map(\.coinId), ["bitcoin"])
    }

    func test_summaryUseCaseReturnsEmptyForNoHoldings() async throws {
        let container = makeSUT()
        let summary = try await container.makeGetPortfolioSummaryUseCase()(currency: .usd)
        XCTAssertEqual(summary, .empty)
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/AppContainerTests`
Expected: FAIL to compile — `value of type 'AppContainer' has no member 'portfolioRepository' / 'makeAddHoldingUseCase'`.

- [ ] **Step 3: Extend `AppContainer`**

In `CryptoPortfolio/Core/DI/AppContainer.swift`, add the following inside the `AppContainer` class body (after the existing stored properties and `init`, before the closing brace of the class). Do NOT change the existing properties, init, or the `EnvironmentKey`/`EnvironmentValues` extension:
```swift
    // MARK: - Repositories (lazy, share the container's infrastructure)

    private(set) lazy var coinRepository: CoinRepository = CoinRepositoryImpl(httpClient: httpClient)
    private(set) lazy var portfolioRepository: PortfolioRepository = PortfolioRepositoryImpl(stack: coreDataStack)

    // MARK: - Use case factories

    func makeSearchCoinsUseCase() -> SearchCoinsUseCase {
        SearchCoinsUseCase(coinRepository: coinRepository)
    }

    func makeAddHoldingUseCase() -> AddHoldingUseCase {
        AddHoldingUseCase(portfolioRepository: portfolioRepository)
    }

    func makeRemoveHoldingUseCase() -> RemoveHoldingUseCase {
        RemoveHoldingUseCase(portfolioRepository: portfolioRepository)
    }

    func makeGetPortfolioSummaryUseCase() -> GetPortfolioSummaryUseCase {
        GetPortfolioSummaryUseCase(portfolioRepository: portfolioRepository, coinRepository: coinRepository)
    }
```

- [ ] **Step 4: Run the test, verify it passes**

Run the same command as Step 2. Expected: `** TEST SUCCEEDED **`, 2 tests pass.

- [ ] **Step 5: Run the FULL suite to confirm no regressions**

Run: `xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: `** TEST SUCCEEDED **`. Total = 18 (Phase 1) + new tests from Tasks 1-10.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Core/DI/AppContainer.swift CryptoPortfolioTests/DI/AppContainerTests.swift
git commit -m "feat: expose Portfolio repositories and use-case factories from AppContainer"
```

---

## Self-Review

**1. Spec coverage (spec §6 Data, §7 Domain — Portfolio-relevant parts):**
- CoinGecko `/coins/markets` + `/search` endpoints → Task 4 ✅
- DTOs + Mappers (DTO → entity) → Tasks 2, 3 ✅
- `CoinRepository` (search/markets) → Task 5 ✅
- `PortfolioRepository` (CRUD holdings) + Core Data `CDHolding` → Task 6 ✅
- Use cases `SearchCoinsUseCase`, `AddHoldingUseCase` (weighted-avg per spec §7), `RemoveHoldingUseCase`, `GetPortfolioSummaryUseCase` (P/L math in domain, not VM) → Tasks 8, 9 ✅
- `PortfolioSummary` entity with per-holding breakdown → Task 7 ✅
- Display currency (`vs_currency`, default usd) → Task 1 + threaded through Tasks 5, 9 ✅
- DI composition root builds repositories/use cases → Task 10 ✅

Deliberately deferred (NOT in 2a): `/coins/{id}/market_chart` + `ChartPoint` mapping (Phase 3); offline cache via `CDCachedCoin` (later enhancement — repo is network-only now, documented in Task 5); all Presentation (ViewModels/Views/refresh stream) → Phase 2b. `Decimal` migration → not doing (Double is the deliberate choice, see header).

**2. Placeholder scan:** No "TBD"/"TODO"/"add validation"-style placeholders; every code step has complete code; every command has expected output. ✅

**3. Type consistency:**
- `CoinRepository.searchCoins(query:)` / `markets(ids:currency:)` identical across protocol (Task 5), impl (Task 5), mocks (Task 8), and call sites (Tasks 9, 10). ✅
- `PortfolioRepository.holdings()/holding(coinId:)/save(_:)/remove(coinId:)` identical across protocol (Task 6), impl (Task 6), mock (Task 8), and call sites (Tasks 8, 9, 10). ✅
- `Currency.code`/`.usd`/`.tryLira`/`.default` consistent (Tasks 1, 5, 9). ✅
- `Coin(...)`/`Holding(...)` initializers match the existing Phase 1 entities (confirmed against current source). ✅
- `HoldingValuation(holding:coin:currentValue:cost:)` + computed `absolutePnL`/`percentPnL`, and `PortfolioSummary(totalValue:totalCost:absolutePnL:percentPnL:items:)` + `.empty` consistent across Tasks 7, 9. ✅
- `PortfolioError.invalidAmount` defined in Task 8 (AddHoldingUseCase.swift), used in Task 8 test. ✅
- `AppContainer` additions (`coinRepository`, `portfolioRepository`, `make*UseCase()`) match Task 10 test usage; `CoinRepositoryImpl(httpClient:)` and `PortfolioRepositoryImpl(stack:)` initializers match Tasks 5, 6. ✅
- `CDHolding` attribute names (`coinId`, `amount`, `averageBuyPrice`, `dateAdded`) match the model (Task 6 Step 1) and the impl's reads/writes (Task 6 Step 4). ✅

No issues found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-25-crypto-portfolio-ios-phase2a-portfolio-core.md`.
