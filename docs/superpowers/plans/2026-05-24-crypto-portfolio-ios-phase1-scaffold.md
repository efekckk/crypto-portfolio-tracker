# Crypto Portfolio Tracker — Faz 1: Scaffold & Core Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a buildable, launchable SwiftUI iOS app skeleton with a fully unit-tested Core layer (networking, rate limiting, Core Data stack, shared domain entities, DI, analytics abstraction).

**Architecture:** Clean Architecture (Presentation → Domain ← Data) with a `Core` foundation. This phase delivers the foundation and an empty 3-tab app; feature work (Portfolio, CoinDetail, Watchlist, Alerts) lands in later phases. XcodeGen generates the project from `project.yml`. No third-party dependencies.

**Tech Stack:** Swift 5 mode (toolchain 6.2.3), SwiftUI, iOS 16+, Swift Concurrency (async/await + actor), Combine, Core Data, URLSession, XcodeGen, XCTest.

Reference spec: `docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` (§4–§9, §14 Phase 1).

---

## File Structure

Files created in this phase (all paths relative to repo root `/Users/efekck/project/crypto-portfolio-tracker`):

| File | Responsibility |
| --- | --- |
| `project.yml` | XcodeGen source of truth: targets, settings, schemes |
| `Config/Base.xcconfig` | Base build settings; optionally includes Secrets |
| `Config/Secrets.xcconfig.example` | Template carrying `COINGECKO_API_KEY` placeholder |
| `CryptoPortfolio/App/CryptoPortfolioApp.swift` | `@main` entry; builds `AppContainer`, injects environment |
| `CryptoPortfolio/App/RootView.swift` | Root `TabView` with 3 placeholder tabs |
| `CryptoPortfolio/Resources/Info.plist` | Bundle config; `COINGECKO_API_KEY` from build setting |
| `CryptoPortfolio/Resources/Assets.xcassets/**` | App icon, accent + semantic colors |
| `CryptoPortfolio/Resources/Localizable.xcstrings` | tr/en strings for tab labels |
| `CryptoPortfolio/Domain/Entities/*.swift` | `Coin`, `Holding`, `ChartPoint`, `PriceAlert`, `PriceRange` |
| `CryptoPortfolio/Core/Config/AppConfig.swift` | Reads `COINGECKO_API_KEY` from Info.plist |
| `CryptoPortfolio/Core/Network/APIError.swift` | Typed network errors |
| `CryptoPortfolio/Core/Network/Endpoint.swift` | Path + query value object |
| `CryptoPortfolio/Core/Network/HTTPClient.swift` | `HTTPClient` protocol + `URLSessionHTTPClient` |
| `CryptoPortfolio/Core/Network/RateLimiter.swift` | Token-bucket actor (~30/min) |
| `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/**` | Core Data model (`CDCachedCoin`) |
| `CryptoPortfolio/Core/Persistence/CoreDataStack.swift` | `NSPersistentContainer` wrapper |
| `CryptoPortfolio/Core/Analytics/AnalyticsService.swift` | `AnalyticsService` + `NoOpAnalytics` |
| `CryptoPortfolio/Core/Analytics/CrashReporter.swift` | `CrashReporter` + `NoOpCrashReporter` |
| `CryptoPortfolio/Core/Theme/Theme.swift` | Semantic color tokens |
| `CryptoPortfolio/Core/DI/AppContainer.swift` | Composition root + `EnvironmentKey` |
| `CryptoPortfolioTests/Support/MockURLProtocol.swift` | URLProtocol stub for HTTPClient tests |
| `CryptoPortfolioTests/Network/HTTPClientTests.swift` | HTTPClient behavior |
| `CryptoPortfolioTests/Network/RateLimiterTests.swift` | Token-bucket behavior |
| `CryptoPortfolioTests/Domain/PriceRangeTests.swift` | CoinGecko `days` mapping |
| `CryptoPortfolioTests/Persistence/CoreDataStackTests.swift` | In-memory save/fetch |

---

## Prerequisite: install XcodeGen

- [ ] **Step 0: Ensure XcodeGen is installed**

Run:
```bash
which xcodegen || brew install xcodegen
xcodegen --version
```
Expected: prints a version (e.g. `Version: 2.x`). If `brew` prompts, allow it.

---

### Task 1: Project scaffold — buildable empty app

**Files:**
- Create: `project.yml`
- Create: `Config/Base.xcconfig`
- Create: `Config/Secrets.xcconfig.example`
- Create: `CryptoPortfolio/Resources/Info.plist`
- Create: `CryptoPortfolio/Resources/Assets.xcassets/Contents.json`
- Create: `CryptoPortfolio/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `CryptoPortfolio/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `CryptoPortfolio/Resources/Localizable.xcstrings`
- Create: `CryptoPortfolio/App/CryptoPortfolioApp.swift`
- Create: `CryptoPortfolio/App/RootView.swift`
- Modify: `.gitignore` (add generated Info.plist exclusion is NOT needed — plist is committed)

- [ ] **Step 1: Create `project.yml`**

```yaml
name: CryptoPortfolio
options:
  bundleIdPrefix: com.foneria.cryptoportfolio
  deploymentTarget:
    iOS: "16.0"
  createIntermediateGroups: true
configs:
  Debug: debug
  Release: release
settings:
  base:
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    DEVELOPMENT_TEAM: ""
    CODE_SIGNING_ALLOWED: "NO"
targets:
  CryptoPortfolio:
    type: application
    platform: iOS
    sources:
      - path: CryptoPortfolio
    configFiles:
      Debug: Config/Base.xcconfig
      Release: Config/Base.xcconfig
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.foneria.cryptoportfolio
        INFOPLIST_FILE: CryptoPortfolio/Resources/Info.plist
        GENERATE_INFOPLIST_FILE: "NO"
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME: AccentColor
  CryptoPortfolioTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: CryptoPortfolioTests
    dependencies:
      - target: CryptoPortfolio
schemes:
  CryptoPortfolio:
    build:
      targets:
        CryptoPortfolio: all
        CryptoPortfolioTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - CryptoPortfolioTests
```

- [ ] **Step 2: Create `Config/Base.xcconfig`**

```
// Base build settings shared by Debug and Release.
// Optionally pulls in a local, gitignored Secrets.xcconfig (see Secrets.xcconfig.example).
#include? "Secrets.xcconfig"
```

- [ ] **Step 3: Create `Config/Secrets.xcconfig.example`**

```
// Copy this file to Config/Secrets.xcconfig (gitignored) and set your CoinGecko Demo API key.
// Leave empty to run keyless against the public endpoint.
COINGECKO_API_KEY =
```

- [ ] **Step 4: Create the local secrets file so the build can resolve the include**

Run:
```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```
(`Config/Secrets.xcconfig` is already gitignored by the repo `.gitignore`.)

- [ ] **Step 5: Create `CryptoPortfolio/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Crypto Portfolio</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>tr</string>
        <string>en</string>
    </array>
    <key>COINGECKO_API_KEY</key>
    <string>$(COINGECKO_API_KEY)</string>
    <key>NSCameraUsageDescription</key>
    <string>QR kodu taramak için kameraya erişim gerekir.</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 6: Create `CryptoPortfolio/Resources/Assets.xcassets/Contents.json`**

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 7: Create `CryptoPortfolio/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`**

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 8: Create `CryptoPortfolio/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`**

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.949",
          "green" : "0.557",
          "red" : "0.275"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 9: Create `CryptoPortfolio/Resources/Localizable.xcstrings`**

```json
{
  "sourceLanguage" : "tr",
  "strings" : {
    "tab.alerts" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Alerts" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Alarmlar" } }
      }
    },
    "tab.portfolio" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Portfolio" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Portföy" } }
      }
    },
    "tab.watchlist" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Watchlist" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "İzleme" } }
      }
    },
    "common.comingSoon" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Coming soon" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Yakında" } }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 10: Create `CryptoPortfolio/App/CryptoPortfolioApp.swift`**

```swift
import SwiftUI

@main
struct CryptoPortfolioApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 11: Create `CryptoPortfolio/App/RootView.swift`**

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            PlaceholderTab(titleKey: "tab.portfolio", systemImage: "chart.pie.fill")
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

- [ ] **Step 12: Generate the Xcode project**

Run:
```bash
cd /Users/efekck/project/crypto-portfolio-tracker && xcodegen generate
```
Expected: `Created project at .../CryptoPortfolio.xcodeproj`.

- [ ] **Step 13: Build for the simulator**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 14: Commit**

```bash
git add project.yml Config/ CryptoPortfolio/ .gitignore
git commit -m "feat: scaffold buildable SwiftUI app skeleton with XcodeGen"
```

---

### Task 2: Shared domain entities + `PriceRange`

**Files:**
- Create: `CryptoPortfolio/Domain/Entities/Coin.swift`
- Create: `CryptoPortfolio/Domain/Entities/Holding.swift`
- Create: `CryptoPortfolio/Domain/Entities/ChartPoint.swift`
- Create: `CryptoPortfolio/Domain/Entities/PriceAlert.swift`
- Create: `CryptoPortfolio/Domain/Entities/PriceRange.swift`
- Test: `CryptoPortfolioTests/Domain/PriceRangeTests.swift`

- [ ] **Step 1: Write the failing test for `PriceRange`**

Create `CryptoPortfolioTests/Domain/PriceRangeTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class PriceRangeTests: XCTestCase {
    func test_coinGeckoDays_mapsEachCaseToExpectedValue() {
        XCTAssertEqual(PriceRange.h24.coinGeckoDays, "1")
        XCTAssertEqual(PriceRange.d7.coinGeckoDays, "7")
        XCTAssertEqual(PriceRange.d30.coinGeckoDays, "30")
        XCTAssertEqual(PriceRange.y1.coinGeckoDays, "365")
    }

    func test_allCases_areInChronologicalOrder() {
        XCTAssertEqual(PriceRange.allCases, [.h24, .d7, .d30, .y1])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/PriceRangeTests
```
Expected: FAILS to compile — `cannot find 'PriceRange' in scope`.

- [ ] **Step 3: Create `CryptoPortfolio/Domain/Entities/PriceRange.swift`**

```swift
import Foundation

/// Chart time ranges offered in CoinDetail, with the CoinGecko `days` parameter.
enum PriceRange: String, CaseIterable, Identifiable {
    case h24
    case d7
    case d30
    case y1

    var id: String { rawValue }

    /// Value for CoinGecko `/coins/{id}/market_chart?days=`.
    var coinGeckoDays: String {
        switch self {
        case .h24: return "1"
        case .d7: return "7"
        case .d30: return "30"
        case .y1: return "365"
        }
    }

    /// Short label for the segmented selector.
    var displayLabel: String {
        switch self {
        case .h24: return "24s"
        case .d7: return "7g"
        case .d30: return "30g"
        case .y1: return "1y"
        }
    }
}
```

- [ ] **Step 4: Create the remaining entity files**

Create `CryptoPortfolio/Domain/Entities/Coin.swift`:
```swift
import Foundation

/// A tradable coin with its latest market snapshot.
struct Coin: Identifiable, Equatable {
    let id: String          // CoinGecko id, e.g. "bitcoin"
    let symbol: String      // e.g. "btc"
    let name: String        // e.g. "Bitcoin"
    let imageURL: URL?
    let currentPrice: Double
    let priceChangePercentage24h: Double

    init(
        id: String,
        symbol: String,
        name: String,
        imageURL: URL? = nil,
        currentPrice: Double = 0,
        priceChangePercentage24h: Double = 0
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
    }
}
```

Create `CryptoPortfolio/Domain/Entities/Holding.swift`:
```swift
import Foundation

/// A user's position in a single coin. One Holding per coin id.
struct Holding: Identifiable, Equatable {
    var id: String { coinId }
    let coinId: String
    let amount: Double          // units held
    let averageBuyPrice: Double // weighted average cost per unit
    let dateAdded: Date

    init(coinId: String, amount: Double, averageBuyPrice: Double, dateAdded: Date = Date()) {
        self.coinId = coinId
        self.amount = amount
        self.averageBuyPrice = averageBuyPrice
        self.dateAdded = dateAdded
    }
}
```

Create `CryptoPortfolio/Domain/Entities/ChartPoint.swift`:
```swift
import Foundation

/// A single (time, price) sample for a performance chart.
struct ChartPoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let price: Double
}
```

Create `CryptoPortfolio/Domain/Entities/PriceAlert.swift`:
```swift
import Foundation

/// A user-defined price threshold for a coin.
struct PriceAlert: Identifiable, Equatable {
    enum Direction: String {
        case above
        case below
    }

    let id: UUID
    let coinId: String
    let targetPrice: Double
    let direction: Direction
    var isActive: Bool
    var firedAt: Date?

    init(
        id: UUID = UUID(),
        coinId: String,
        targetPrice: Double,
        direction: Direction,
        isActive: Bool = true,
        firedAt: Date? = nil
    ) {
        self.id = id
        self.coinId = coinId
        self.targetPrice = targetPrice
        self.direction = direction
        self.isActive = isActive
        self.firedAt = firedAt
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/PriceRangeTests
```
Expected: `** TEST SUCCEEDED **` (both PriceRange tests pass).

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Domain CryptoPortfolioTests/Domain
git commit -m "feat: add shared domain entities and PriceRange mapping"
```

---

### Task 3: Networking layer (`HTTPClient`)

**Files:**
- Create: `CryptoPortfolio/Core/Config/AppConfig.swift`
- Create: `CryptoPortfolio/Core/Network/APIError.swift`
- Create: `CryptoPortfolio/Core/Network/Endpoint.swift`
- Create: `CryptoPortfolio/Core/Network/HTTPClient.swift`
- Create: `CryptoPortfolioTests/Support/MockURLProtocol.swift`
- Test: `CryptoPortfolioTests/Network/HTTPClientTests.swift`

- [ ] **Step 1: Create the test support `MockURLProtocol`**

Create `CryptoPortfolioTests/Support/MockURLProtocol.swift`:
```swift
import Foundation

/// A URLProtocol that returns canned responses for unit tests.
final class MockURLProtocol: URLProtocol {
    /// Set before each test. Receives the outgoing request, returns (response, body).
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Write the failing tests for `HTTPClient`**

Create `CryptoPortfolioTests/Network/HTTPClientTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

private struct StubResponse: Decodable, Equatable {
    let value: String
}

final class HTTPClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    private func makeSUT(apiKey: String? = nil) -> URLSessionHTTPClient {
        URLSessionHTTPClient(
            session: MockURLProtocol.makeSession(),
            baseURL: URL(string: "https://example.com/api/v3")!,
            apiKey: apiKey
        )
    }

    func test_send_decodesSuccessfulJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, #"{"value":"ok"}"#.data(using: .utf8)!)
        }
        let sut = makeSUT()

        let result = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)

        XCTAssertEqual(result, StubResponse(value: "ok"))
    }

    func test_send_buildsURLWithPathAndQueryAndAPIKeyHeader() async throws {
        var captured: URLRequest?
        MockURLProtocol.requestHandler = { request in
            captured = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, #"{"value":"ok"}"#.data(using: .utf8)!)
        }
        let sut = makeSUT(apiKey: "demo-key")

        _ = try await sut.send(
            Endpoint(path: "coins/markets", queryItems: [URLQueryItem(name: "vs_currency", value: "usd")]),
            as: StubResponse.self
        )

        XCTAssertEqual(captured?.url?.absoluteString, "https://example.com/api/v3/coins/markets?vs_currency=usd")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "x-cg-demo-api-key"), "demo-key")
    }

    func test_send_omitsAPIKeyHeaderWhenKeyIsNil() async throws {
        var captured: URLRequest?
        MockURLProtocol.requestHandler = { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"value":"ok"}"#.data(using: .utf8)!)
        }
        let sut = makeSUT(apiKey: nil)

        _ = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)

        XCTAssertNil(captured?.value(forHTTPHeaderField: "x-cg-demo-api-key"))
    }

    func test_send_throwsRateLimitedOn429() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let sut = makeSUT()

        await assertThrows(sut, expected: .rateLimited)
    }

    func test_send_throwsRequestFailedOnServerError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let sut = makeSUT()

        await assertThrows(sut, expected: .requestFailed(statusCode: 500))
    }

    func test_send_throwsDecodingOnMalformedJSON() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }
        let sut = makeSUT()

        do {
            _ = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)
            XCTFail("Expected to throw")
        } catch let error as APIError {
            if case .decoding = error { /* ok */ } else { XCTFail("Expected .decoding, got \(error)") }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: - Helpers

    private func assertThrows(_ sut: URLSessionHTTPClient, expected: APIError,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)
            XCTFail("Expected to throw", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected APIError, got \(error)", file: file, line: line)
        }
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/HTTPClientTests
```
Expected: FAILS to compile — `cannot find 'URLSessionHTTPClient' / 'Endpoint' / 'APIError' in scope`.

- [ ] **Step 4: Create `CryptoPortfolio/Core/Network/APIError.swift`**

```swift
import Foundation

enum APIError: Error, Equatable {
    case invalidURL
    case requestFailed(statusCode: Int)
    case rateLimited
    case decoding(String)
    case transport(String)
}
```

- [ ] **Step 5: Create `CryptoPortfolio/Core/Network/Endpoint.swift`**

```swift
import Foundation

/// A relative API path plus query items, resolved against the client's base URL.
struct Endpoint {
    let path: String
    let queryItems: [URLQueryItem]

    init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }
}
```

- [ ] **Step 6: Create `CryptoPortfolio/Core/Config/AppConfig.swift`**

```swift
import Foundation

/// Runtime configuration sourced from the Info.plist (populated by xcconfig).
enum AppConfig {
    static let coinGeckoBaseURL = URL(string: "https://api.coingecko.com/api/v3")!

    /// CoinGecko Demo API key, or nil when running keyless.
    static var coinGeckoAPIKey: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "COINGECKO_API_KEY") as? String
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
```

- [ ] **Step 7: Create `CryptoPortfolio/Core/Network/HTTPClient.swift`**

```swift
import Foundation

protocol HTTPClient {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String?
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        baseURL: URL = AppConfig.coinGeckoBaseURL,
        apiKey: String? = AppConfig.coinGeckoAPIKey,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.decoder = decoder
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Non-HTTP response")
        }
        if http.statusCode == 429 { throw APIError.rateLimited }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.requestFailed(statusCode: http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
```

- [ ] **Step 8: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/HTTPClientTests
```
Expected: `** TEST SUCCEEDED **` — all 6 tests pass.

- [ ] **Step 9: Commit**

```bash
git add CryptoPortfolio/Core/Network CryptoPortfolio/Core/Config CryptoPortfolioTests/Support CryptoPortfolioTests/Network/HTTPClientTests.swift
git commit -m "feat: add URLSession HTTPClient with typed errors and API key header"
```

---

### Task 4: `RateLimiter` (token bucket)

**Files:**
- Create: `CryptoPortfolio/Core/Network/RateLimiter.swift`
- Test: `CryptoPortfolioTests/Network/RateLimiterTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `CryptoPortfolioTests/Network/RateLimiterTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class RateLimiterTests: XCTestCase {
    func test_allowsUpToCapacityThenBlocks() async {
        var now = Date(timeIntervalSince1970: 0)
        let limiter = RateLimiter(capacity: 3, perInterval: 3, now: { now })

        let r1 = await limiter.tryConsume()
        let r2 = await limiter.tryConsume()
        let r3 = await limiter.tryConsume()
        let r4 = await limiter.tryConsume()

        XCTAssertEqual([r1, r2, r3], [true, true, true])
        XCTAssertFalse(r4)
    }

    func test_refillsOneTokenAfterRefillInterval() async {
        var now = Date(timeIntervalSince1970: 0)
        // capacity 2 over 2s => one token every 1s.
        let limiter = RateLimiter(capacity: 2, perInterval: 2, now: { now })

        _ = await limiter.tryConsume()
        _ = await limiter.tryConsume()
        XCTAssertFalse(await limiter.tryConsume(), "Bucket should be empty")

        now = now.addingTimeInterval(1) // refill exactly one token
        XCTAssertTrue(await limiter.tryConsume(), "One token should have refilled")
        XCTAssertFalse(await limiter.tryConsume(), "Only one token should refill")
    }

    func test_doesNotOverfillBeyondCapacity() async {
        var now = Date(timeIntervalSince1970: 0)
        let limiter = RateLimiter(capacity: 2, perInterval: 2, now: { now })

        now = now.addingTimeInterval(100) // long idle; must cap at capacity
        let r1 = await limiter.tryConsume()
        let r2 = await limiter.tryConsume()
        let r3 = await limiter.tryConsume()

        XCTAssertEqual([r1, r2], [true, true])
        XCTAssertFalse(r3)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/RateLimiterTests
```
Expected: FAILS to compile — `cannot find 'RateLimiter' in scope`.

- [ ] **Step 3: Create `CryptoPortfolio/Core/Network/RateLimiter.swift`**

```swift
import Foundation

/// Token-bucket limiter to respect the CoinGecko Demo tier (~30 requests/minute).
/// `now` is injectable for deterministic tests.
actor RateLimiter {
    private let capacity: Double
    private let refillInterval: TimeInterval // seconds to refill exactly one token
    private let now: () -> Date

    private var tokens: Double
    private var lastRefill: Date

    init(capacity: Int = 30, perInterval seconds: TimeInterval = 60, now: @escaping () -> Date = Date.init) {
        self.capacity = Double(capacity)
        self.refillInterval = seconds / Double(capacity)
        self.tokens = Double(capacity)
        self.now = now
        self.lastRefill = now()
    }

    /// Consumes one token if available. Returns false when the bucket is empty.
    func tryConsume() -> Bool {
        refill()
        guard tokens >= 1 else { return false }
        tokens -= 1
        return true
    }

    private func refill() {
        let current = now()
        let elapsed = current.timeIntervalSince(lastRefill)
        guard elapsed > 0 else { return }
        tokens = min(capacity, tokens + elapsed / refillInterval)
        lastRefill = current
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/RateLimiterTests
```
Expected: `** TEST SUCCEEDED **` — all 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Core/Network/RateLimiter.swift CryptoPortfolioTests/Network/RateLimiterTests.swift
git commit -m "feat: add token-bucket RateLimiter for CoinGecko demo tier"
```

---

### Task 5: Core Data stack + model

**Files:**
- Create: `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents`
- Create: `CryptoPortfolio/Core/Persistence/CoreDataStack.swift`
- Test: `CryptoPortfolioTests/Persistence/CoreDataStackTests.swift`

- [ ] **Step 1: Create the Core Data model**

Create `CryptoPortfolio/Core/Persistence/CryptoPortfolio.xcdatamodeld/CryptoPortfolio.xcdatamodel/contents`:
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
</model>
```

- [ ] **Step 2: Write the failing test**

Create `CryptoPortfolioTests/Persistence/CoreDataStackTests.swift`:
```swift
import XCTest
import CoreData
@testable import CryptoPortfolio

final class CoreDataStackTests: XCTestCase {
    func test_inMemoryStack_savesAndFetchesCachedCoin() throws {
        let stack = CoreDataStack(inMemory: true)
        let context = stack.viewContext

        let coin = CDCachedCoin(context: context)
        coin.id = "bitcoin"
        coin.symbol = "btc"
        coin.name = "Bitcoin"
        coin.currentPrice = 50_000
        coin.priceChangePercentage24h = 2.5
        coin.updatedAt = Date()
        try context.save()

        let request = NSFetchRequest<CDCachedCoin>(entityName: "CDCachedCoin")
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "bitcoin")
        XCTAssertEqual(results.first?.currentPrice, 50_000)
    }

    func test_inMemoryStack_startsEmpty() throws {
        let stack = CoreDataStack(inMemory: true)
        let request = NSFetchRequest<CDCachedCoin>(entityName: "CDCachedCoin")
        let results = try stack.viewContext.fetch(request)
        XCTAssertEqual(results.count, 0)
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CoreDataStackTests
```
Expected: FAILS to compile — `cannot find 'CoreDataStack' in scope`.

- [ ] **Step 4: Create `CryptoPortfolio/Core/Persistence/CoreDataStack.swift`**

```swift
import CoreData

/// Wraps NSPersistentContainer. `inMemory` gives an isolated store for tests.
final class CoreDataStack {
    let container: NSPersistentContainer

    init(inMemory: Bool = false, modelName: String = "CryptoPortfolio") {
        container = NSPersistentContainer(name: modelName)
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:CryptoPortfolioTests/CoreDataStackTests
```
Expected: `** TEST SUCCEEDED **` — both tests pass. (`CDCachedCoin` is generated from the model at build time.)

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Core/Persistence CryptoPortfolioTests/Persistence
git commit -m "feat: add Core Data stack with CDCachedCoin model"
```

---

### Task 6: Analytics abstraction, Theme tokens, DI composition root

**Files:**
- Create: `CryptoPortfolio/Core/Analytics/AnalyticsService.swift`
- Create: `CryptoPortfolio/Core/Analytics/CrashReporter.swift`
- Create: `CryptoPortfolio/Core/Theme/Theme.swift`
- Create: `CryptoPortfolio/Resources/Assets.xcassets/Positive.colorset/Contents.json`
- Create: `CryptoPortfolio/Resources/Assets.xcassets/Negative.colorset/Contents.json`
- Create: `CryptoPortfolio/Core/DI/AppContainer.swift`
- Modify: `CryptoPortfolio/App/CryptoPortfolioApp.swift`

- [ ] **Step 1: Create `CryptoPortfolio/Core/Analytics/AnalyticsService.swift`**

```swift
import Foundation

/// Abstraction over an analytics backend. Firebase slots in behind this later.
protocol AnalyticsService {
    func track(_ event: String, parameters: [String: Any])
}

extension AnalyticsService {
    func track(_ event: String) { track(event, parameters: [:]) }
}

/// Default implementation that does nothing (no backend wired yet).
struct NoOpAnalytics: AnalyticsService {
    func track(_ event: String, parameters: [String: Any]) {}
}
```

- [ ] **Step 2: Create `CryptoPortfolio/Core/Analytics/CrashReporter.swift`**

```swift
import Foundation

/// Abstraction over a crash-reporting backend (e.g. Crashlytics later).
protocol CrashReporter {
    func record(_ error: Error)
    func log(_ message: String)
}

struct NoOpCrashReporter: CrashReporter {
    func record(_ error: Error) {}
    func log(_ message: String) {}
}
```

- [ ] **Step 3: Create the semantic color assets**

Create `CryptoPortfolio/Resources/Assets.xcassets/Positive.colorset/Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.400", "green" : "0.780", "red" : "0.200" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.450", "green" : "0.850", "red" : "0.300" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Create `CryptoPortfolio/Resources/Assets.xcassets/Negative.colorset/Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.250", "green" : "0.230", "red" : "0.900" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.300", "green" : "0.300", "red" : "1.000" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: Create `CryptoPortfolio/Core/Theme/Theme.swift`**

```swift
import SwiftUI

/// Semantic color tokens backed by asset-catalog colors that adapt to dark/light.
/// Views use these instead of hard-coded colors.
enum Theme {
    static let accent = Color.accentColor
    static let positive = Color("Positive")
    static let negative = Color("Negative")

    /// Color for a signed change value: positive green, negative red.
    static func color(forChange value: Double) -> Color {
        value >= 0 ? positive : negative
    }
}
```

- [ ] **Step 5: Create `CryptoPortfolio/Core/DI/AppContainer.swift`**

```swift
import SwiftUI

/// Composition root: owns long-lived dependencies and builds use cases/view models.
/// Feature wiring is added in later phases.
final class AppContainer {
    let httpClient: HTTPClient
    let rateLimiter: RateLimiter
    let coreDataStack: CoreDataStack
    let analytics: AnalyticsService
    let crashReporter: CrashReporter

    init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        rateLimiter: RateLimiter = RateLimiter(),
        coreDataStack: CoreDataStack = CoreDataStack(),
        analytics: AnalyticsService = NoOpAnalytics(),
        crashReporter: CrashReporter = NoOpCrashReporter()
    ) {
        self.httpClient = httpClient
        self.rateLimiter = rateLimiter
        self.coreDataStack = coreDataStack
        self.analytics = analytics
        self.crashReporter = crashReporter
    }
}

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue = AppContainer()
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
```

- [ ] **Step 6: Wire the container into the app entry point**

Replace the contents of `CryptoPortfolio/App/CryptoPortfolioApp.swift` with:
```swift
import SwiftUI

@main
struct CryptoPortfolioApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appContainer, container)
        }
    }
}
```

- [ ] **Step 7: Regenerate and build the full app + run all tests**

Run:
```bash
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```
Expected: `** TEST SUCCEEDED **` — the whole suite (PriceRange, HTTPClient, RateLimiter, CoreDataStack) is green and the app builds.

- [ ] **Step 8: Commit**

```bash
git add CryptoPortfolio/Core/Analytics CryptoPortfolio/Core/Theme CryptoPortfolio/Core/DI \
        CryptoPortfolio/Resources/Assets.xcassets CryptoPortfolio/App/CryptoPortfolioApp.swift
git commit -m "feat: add analytics abstraction, theme tokens, and DI composition root"
```

---

### Task 7: README + architecture doc + manual launch verification

**Files:**
- Create: `README.md`
- Create: `docs/architecture.md`

- [ ] **Step 1: Create `README.md`**

```markdown
# Crypto Portfolio Tracker — iOS

Native SwiftUI crypto portfolio tracker (Clean Architecture, MVVM). See
`docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` for the full design.

## Requirements
- Xcode 15+ (Swift 5.9+ toolchain), iOS 16+ simulator
- [XcodeGen](https://github.com/yonyz/XcodeGen): `brew install xcodegen`

## Setup
```bash
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
# Optionally set COINGECKO_API_KEY (CoinGecko Demo key) in Config/Secrets.xcconfig
xcodegen generate
open CryptoPortfolio.xcodeproj
```

## Build & test (CLI)
```bash
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Notes
- Price alerts are local and best-effort (background refresh), not guaranteed real-time
  — a push backend would be a separate project. See `docs/architecture.md`.
```

- [ ] **Step 2: Create `docs/architecture.md`**

```markdown
# Architecture

Clean Architecture with strict dependency direction: **Presentation → Domain ← Data**.
Domain is pure Swift; Data and Presentation depend on it via protocols. A `Core` layer
holds cross-cutting infrastructure (Network, Persistence, DI, Theme, Localization,
Analytics).

## Layers
- **Domain** — entities (`Coin`, `Holding`, `PriceAlert`, `ChartPoint`, `PriceRange`),
  repository protocols, use cases. No framework imports.
- **Data** — DTOs, CoinGecko `HTTPClient`, Core Data, repository implementations, mappers.
- **Presentation** — SwiftUI views + `@MainActor` view models (MVVM).
- **Core** — `URLSessionHTTPClient`, `RateLimiter` (token bucket, CoinGecko demo tier),
  `CoreDataStack`, `AppContainer` (DI), `Theme`, analytics/crash protocols.

## Alerts limitation
Real-time push is not possible on the free CoinGecko tier without a backend. Alerts are
evaluated on `BGTaskScheduler` background refresh (iOS-throttled, best-effort) and while
the app is foreground, firing local notifications. A push pipeline is a future project.
```

- [ ] **Step 3: (Optional) Launch in the simulator to eyeball the UI**

Run:
```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build
xcrun simctl install booted "$(find build/Build/Products -name 'CryptoPortfolio.app' | head -1)"
xcrun simctl launch booted com.foneria.cryptoportfolio
```
Expected: the app launches showing a TabView with **Portföy / İzleme / Alarmlar** tabs, each showing an icon, title, and "Yakında".

- [ ] **Step 4: Commit**

```bash
git add README.md docs/architecture.md
git commit -m "docs: add README and architecture overview"
```

---

## Self-Review

**1. Spec coverage (Phase 1 scope per spec §14):**
- Scaffold / buildable empty app → Task 1 ✅
- Core: Network (`HTTPClient`, `Endpoint`, `APIError`, `RateLimiter`) → Tasks 3, 4 ✅
- Core: Persistence (`CoreDataStack` + model) → Task 5 ✅
- Core: DI (`AppContainer`) → Task 6 ✅
- Core: Theme (semantic tokens) → Task 6 ✅ (fuller theming polish deferred to Phase 7 per spec)
- Core: L10n (`Localizable.xcstrings`, tr/en) → Task 1 ✅ (full localization pass deferred to Phase 7)
- Core: Analytics protocols + no-op → Task 6 ✅
- Shared Domain entities → Task 2 ✅
- Config/secrets (`xcconfig` → Info.plist → `AppConfig`) → Tasks 1, 3 ✅

Not in Phase 1 (correctly deferred): repositories, use cases, features (Portfolio/Watchlist/CoinDetail/Alerts), charts, QR, BGTaskScheduler, notifications, in-app language toggle. These have their own later plans.

**2. Placeholder scan:** No "TBD"/"TODO"/"add error handling" placeholders; every code step has complete code; every command has expected output. ✅

**3. Type consistency:**
- `Endpoint(path:queryItems:)`, `APIError` cases, and `HTTPClient.send(_:as:)` are used identically in `HTTPClientTests` and `URLSessionHTTPClient`. ✅
- `RateLimiter(capacity:perInterval:now:)` + `tryConsume()` match between test and impl. ✅
- `CoreDataStack(inMemory:)`, `viewContext`, and `CDCachedCoin` attribute names (`id`, `symbol`, `name`, `imageURL`, `currentPrice`, `priceChangePercentage24h`, `updatedAt`) match between model, test, and stack. ✅
- `AppConfig.coinGeckoBaseURL` / `coinGeckoAPIKey` consumed by `URLSessionHTTPClient` defaults. ✅
- `AppContainer` property names (`httpClient`, `rateLimiter`, `coreDataStack`, `analytics`, `crashReporter`) consistent. ✅
- `Coin.priceChangePercentage24h` (domain) intentionally mirrors the cached-coin attribute name for clean mapping in Phase 2. ✅

No issues found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-24-crypto-portfolio-ios-phase1-scaffold.md`.
