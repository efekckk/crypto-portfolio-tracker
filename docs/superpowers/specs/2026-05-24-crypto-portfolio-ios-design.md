# Crypto Portfolio Tracker — iOS Design Spec

- **Date:** 2026-05-24
- **Status:** Approved (design); implementation plan pending
- **Scope:** Full iOS application in one design. Android is a separate future project.

## 1. Purpose

A native iOS crypto portfolio tracker that mirrors a professional "fund portfolio
management" experience as a standalone fintech product. Users add crypto holdings,
see live prices, portfolio value and profit/loss, browse performance charts, keep a
watchlist, and set price alerts. Built to demo well to clients and to showcase clean
mobile architecture.

## 2. Goals & non-goals

**Goals**
- Add holdings (manual search + amount/buy price), see real-time-ish price, portfolio
  value, and profit/loss (P/L).
- Performance charts: 24h, 7d, 30d, 1y (Swift Charts).
- Watchlist separate from portfolio.
- Local price alerts via background refresh + foreground evaluation.
- Portfolio-item share via app-generated QR (`coinId + amount`).
- Dark/light mode; Turkish + English localization.
- Clean Architecture (Data / Domain / Presentation), MVVM, fully unit-tested domain.

**Non-goals (this cycle)**
- Android app (separate project).
- A push backend / websockets / guaranteed real-time alerts.
- Firebase wired in (abstracted now, integrated later).
- Wallet-address scanning or on-chain integration.
- User accounts / cloud sync.

## 3. Decisions

| Topic | Decision |
| --- | --- |
| Platform | iOS 16+, Swift 5.9+ (toolchain present: Swift 6.2.3, Xcode) |
| UI | SwiftUI, MVVM, `@MainActor` ViewModels |
| Concurrency | Swift Concurrency (async/await) + Combine for streams |
| Persistence | Core Data (user data + lightweight price cache) |
| Networking | URLSession + CoinGecko REST |
| Charts | Apple Swift Charts (system framework) |
| Notifications | UserNotifications + BGTaskScheduler |
| QR | CoreImage (generate) + AVFoundation (scan), app-defined format |
| CoinGecko tier | Demo API key (`x-cg-demo-api-key`, ~30 req/min) |
| Firebase | Deferred — abstracted behind protocols, no-op default |
| Project gen | XcodeGen (`project.yml`), single app target |
| Third-party deps | **None** for v1 (all system frameworks) |

## 4. Architecture

Clean Architecture with strict dependency direction: **Presentation → Domain ← Data**.
Domain is pure Swift (no UIKit/SwiftUI/CoreData). Data and Presentation depend on
Domain via protocols.

```
┌─────────────────────────────────────────────┐
│ Presentation  SwiftUI Views + ViewModels      │  imports Domain
│   (MVVM, @MainActor, Combine/async)            │
├─────────────────────────────────────────────┤
│ Domain        Entities · UseCases · Repo       │  imports nothing
│   protocols (pure Swift, fully unit-tested)    │
├─────────────────────────────────────────────┤
│ Data          DTOs · API client · Core Data ·  │  imports Domain
│   Repository impls · Mappers                   │
└─────────────────────────────────────────────┘
        Core (Network, Persistence, DI, Extensions, Theme, L10n, Analytics)
```

- **ViewModels** are `@MainActor`, expose `@Published` state, call use cases via
  `async/await`. Combine drives the price-refresh stream and alert evaluation.
- **Use cases** are small single-purpose structs depending only on repository
  protocols, making them trivial to unit-test with mock repositories.
- **Repositories**: protocol in Domain, implementation in Data. Implementations merge
  the remote API with the Core Data cache (cache-first, then refresh).
- **DI**: a lightweight `AppContainer` composition root (no third-party DI) builds
  repositories/use cases and injects ViewModels.

## 5. Project structure

```
CryptoPortfolioTracker-iOS/
├── project.yml                 # XcodeGen source of truth
├── .gitignore                  # ignores Secrets.xcconfig, build artifacts
├── README.md
├── Config/
│   ├── Base.xcconfig
│   └── Secrets.xcconfig.example # COINGECKO_API_KEY placeholder
├── CryptoPortfolio/
│   ├── App/                     # CryptoPortfolioApp, RootView, AppContainer (DI)
│   ├── Core/
│   │   ├── Network/             # HTTPClient, Endpoint, APIError, RateLimiter
│   │   ├── Persistence/         # CoreDataStack, NSManagedObject subclasses, .xcdatamodeld
│   │   ├── DI/                  # AppContainer + protocols
│   │   ├── Theme/               # Colors, Typography, dark/light tokens
│   │   ├── Localization/        # Localizable.xcstrings (tr, en)
│   │   ├── Analytics/           # AnalyticsService + CrashReporter protocols + NoOp impls
│   │   └── Extensions/
│   ├── Features/
│   │   ├── Portfolio/  {Data, Domain, Presentation}
│   │   ├── Watchlist/  {Data, Domain, Presentation}
│   │   ├── CoinDetail/ {Data, Domain, Presentation}   # charts live here
│   │   └── Alerts/     {Data, Domain, Presentation}
│   └── Resources/               # Assets.xcassets, Info.plist
├── CryptoPortfolioTests/        # mirrors Features/ + Core
└── docs/
    ├── architecture.md
    └── screenshots/
```

Shared concerns the four features all touch — the CoinGecko client, the price-refresh
stream, the Core Data stack, and the shared coin/price domain entities — live in `Core`
and a shared `Domain`, not duplicated per feature.

## 6. Data layer

- **`HTTPClient`** (protocol + URLSession impl): async generic
  `request(_ endpoint: Endpoint) async throws -> T where T: Decodable`. Injects the
  `x-cg-demo-api-key` header from build config. A **`RateLimiter`** (token bucket,
  ~30/min) throttles calls to respect the demo tier.
- **CoinGecko endpoints**:
  - `/coins/markets` — list + prices + 24h change.
  - `/coins/{id}/market_chart` — time series for 24h / 7d / 30d / 1y.
  - `/search` — add-coin search.
  - `/simple/price` — lightweight refresh polling.
- **DTOs** decode responses; **Mappers** convert DTO → Domain entity.
- **Core Data** persists user data (`CDHolding`, `CDWatchItem`, `CDAlert`) plus a
  lightweight price cache (`CDCachedCoin`) with timestamps for instant/offline display.
  `CoreDataStack` wraps `NSPersistentContainer` with a background context for writes.
- **Repository impls** (`PortfolioRepositoryImpl`, `CoinRepositoryImpl`,
  `WatchlistRepositoryImpl`, `AlertRepositoryImpl`) implement Domain protocols, merging
  live data with persisted data and returning Domain entities (cache-first then refresh).

## 7. Domain layer

Pure Swift, no framework imports.

- **Entities:** `Coin` (id, symbol, name, imageURL, currentPrice, change24h…),
  `Holding` (coin, amount, avgBuyPrice, dateAdded), `PortfolioSummary` (totalValue,
  totalCost, absolutePnL, percentPnL, per-holding breakdown), `PriceAlert` (coinId,
  targetPrice, direction `.above`/`.below`, isActive, firedAt?), `ChartPoint`
  (date, price), `PriceRange` enum (`.h24`/`.d7`/`.d30`/`.y1`).
- **Repository protocols:** `CoinRepository`, `PortfolioRepository`,
  `WatchlistRepository`, `AlertRepository`.
- **Use cases** (single-purpose structs): `SearchCoinsUseCase`, `AddHoldingUseCase`,
  `RemoveHoldingUseCase`, `GetPortfolioSummaryUseCase` (P/L math),
  `GetCoinChartUseCase`, `ToggleWatchlistUseCase`, `CreateAlertUseCase`,
  `EvaluateAlertsUseCase`. P/L and alert-evaluation logic lives here, never in
  ViewModels, so it is unit-tested in isolation.
- **Holding aggregation:** one `Holding` per coin. Adding more of a coin the user
  already holds updates the amount and recomputes the **weighted average buy price**;
  v1 keeps no per-lot transaction history (a future enhancement).

## 8. Presentation layer

`RootView` = `TabView` with three tabs: **Portfolio · Watchlist · Alerts**. CoinDetail
is pushed via `NavigationStack` from any list. Each screen = SwiftUI `View` +
`@MainActor` `ViewModel` exposing a `ViewState` enum
(`.loading` / `.loaded` / `.empty` / `.error`).

- **Portfolio:** summary header (total value, P/L absolute + %, color-coded), holdings
  list, pull-to-refresh, "+" → **AddCoin** sheet (search → pick coin → enter amount +
  buy price). AddCoin offers **scan QR** (AVFoundation); each holding can **generate a
  share QR** (CoreImage) encoding `coinId + amount`.
- **Watchlist:** searchable coin list, star-toggle add/remove, live price + 24h change;
  tap → CoinDetail.
- **CoinDetail:** price header, **Swift Charts** line chart with `.h24`/`.d7`/`.d30`/
  `.y1` segmented selector, stats (market cap, 24h high/low), quick actions (add to
  portfolio / watchlist / create alert).
- **Alerts:** list with active toggle, swipe-to-delete, "+" → create alert (coin +
  target price + above/below). Fired alerts show a fired state.

Reusable presentation kit: `AsyncImageView`, `PriceChangeLabel`, `LoadingView`,
`ErrorView`, `EmptyStateView`, `MiniSparkline`.

## 9. Cross-cutting concerns

- **Price refresh:** `PriceStreamService` exposes a Combine publisher polling
  `/simple/price` on a configurable interval (default 60s) while a screen is
  foreground; ViewModels subscribe. Respects the `RateLimiter`. No websockets (free
  tier has none).
- **Display currency:** a single app-wide display currency setting, default `usd` with
  `try` available, passed as CoinGecko's `vs_currency` and used by all formatters. P/L
  and totals are shown in the selected currency.
- **Theming:** `Theme` with semantic color/typography tokens backed by asset-catalog
  colors that auto-adapt to dark/light. No hard-coded colors in views.
- **Localization:** `Localizable.xcstrings` String Catalog with Turkish + English
  (`tr` is base). Currency/number/date via locale-aware formatters. In-app language
  toggle overrides `Locale`.
- **Analytics abstraction:** `AnalyticsService` + `CrashReporter` protocols injected via
  DI, `NoOpAnalytics` default. Firebase slots in later behind these without touching
  call sites.
- **Config/secrets:** `COINGECKO_API_KEY` flows from `Secrets.xcconfig` → `Info.plist`
  → runtime. `Secrets.xcconfig.example` is committed; the real file is gitignored. The
  app degrades gracefully (keyless public endpoints) if no key is set.

## 10. Alerts design

Local-only and explicitly best-effort:
- `BGTaskScheduler` registers a `BGAppRefreshTask`; on wake it runs
  `EvaluateAlertsUseCase` over active alerts, fetches prices, fires **local**
  `UserNotifications` for crossed thresholds, and marks them fired.
- Foreground: `PriceStreamService` also feeds `EvaluateAlertsUseCase`, so alerts fire
  live while the app is open.
- iOS controls background wake frequency, so background alerts are **not guaranteed
  real-time** — this is documented in `README.md` / `docs/architecture.md`. A true push
  pipeline would be a separate backend sub-project.

## 11. QR format

App-defined, versioned payload encoding a single portfolio item, e.g.
`cptp://v1?coin=<coinId>&amount=<decimal>`. CoreImage (`CIFilter.qrCodeGenerator`)
generates; AVFoundation (`AVCaptureMetadataOutput`) scans. Unknown/invalid payloads are
rejected with a user-facing error. No wallet addresses or on-chain data.

## 12. Testing strategy (TDD)

XCTest, test-first per the test-driven-development discipline. Tests mirror the source
tree.
- **Domain use cases** — full coverage with hand-written mock repositories (P/L math,
  alert evaluation, edge cases: zero/negative amounts, empty portfolio).
- **Mappers** — DTO→entity, including malformed/missing fields.
- **Repositories** — stubbed `HTTPClient` + in-memory Core Data store.
- **ViewModels** — state transitions (loading→loaded/error) with mock use cases.
- **`RateLimiter`** — throttling behavior.
- Live-network calls are **not** unit-tested; integration is verified manually on the
  simulator and via `xcodebuild build`/`test` runs.

## 13. Build & verification

- `xcodegen generate` produces `CryptoPortfolio.xcodeproj` from `project.yml`.
- `xcodebuild -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' build test`
  builds and runs the test suite.
- XcodeGen is installed via Homebrew (`brew install xcodegen`).

## 14. Implementation phasing (for the plan)

The spec covers the whole app; the implementation plan sequences it so something is
always runnable:
1. Scaffold: `project.yml`, config, Core (Network, Persistence, DI, Theme, L10n,
   Analytics protocols), shared Domain entities — buildable empty app.
2. Portfolio vertical slice: search, add holding, summary + P/L, persistence, refresh.
3. CoinDetail + Swift Charts (ranges).
4. Watchlist.
5. Alerts (foreground evaluation, then BGTaskScheduler + notifications).
6. QR generate/scan.
7. Localization pass (tr/en), theming polish, README + architecture docs, screenshots.

## 15. Future / separate projects

- Android app (Kotlin, Compose, Hilt, Room, Retrofit/Moshi, WorkManager, Vico) —
  mirrors this architecture.
- Push backend for real-time alerts.
- Firebase Analytics + Crashlytics integration behind the existing protocols.
