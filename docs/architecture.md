# Architecture

Clean Architecture with strict dependency direction:
**Presentation → Domain ← Data**. Domain is pure Swift; Data and Presentation
depend on Domain via protocols. A `Core` layer holds cross-cutting infrastructure
(Network, Persistence, DI, Theme, Notifications, QR).

## Layers
- **Domain** — entities (`Coin`, `Holding`, `PriceAlert`, `ChartPoint`,
  `PriceRange`, `Currency`, `WatchItem`, `PortfolioShareCode`), repository
  protocols, use cases (P/L math, weighted-avg holding merge, alert evaluation
  threshold logic). No framework imports.
- **Data** — CoinGecko DTOs (`CoinMarketDTO`, `CoinSearchDTO`, `MarketChartDTO`),
  mappers (`CoinMapper`, `ChartPointMapper`), Core Data persistence
  (`CoreDataStack`, `CDCachedCoin`, `CDHolding`, `CDWatchItem`, `CDAlert`),
  repository implementations.
- **Presentation** — SwiftUI views + `@MainActor` view models. Each screen has a
  `ViewState<T>` state machine (`.loading / .loaded / .empty / .error`).
- **Core** — `URLSessionHTTPClient` (typed errors), `RateLimitedHTTPClient`
  decorator (token-bucket against CoinGecko's demo tier), `CoreDataStack`,
  `AppContainer` (DI composition root, no third-party DI), `Theme`,
  `CurrencyFormatter`, `NotificationService` (`UNUserNotificationCenter`),
  `QRCodeGenerator`/`QRCodeScannerView`/`PortfolioShareCodec`.

## Dependency Injection
`AppContainer` is a single composition root constructed in `@main`'s `App`
struct and injected via `EnvironmentValues.appContainer`. Each feature view's
`init(container:)` constructs its `@StateObject` view model from
`container.make*UseCase()` factories.

## Alerts limitation
Real-time push is not possible on the free CoinGecko tier without a backend.
Alerts are evaluated on `BGTaskScheduler` background refresh (iOS-throttled,
best-effort), while the app is foreground via `.task`/`.refreshable`, and after
each Create/Toggle/Delete. Local `UserNotifications` fire on threshold crossings.

## QR share format
Portfolio items are shareable as `cptp://v1?coin=<coinId>&amount=<decimal>`
URLs encoded into QR codes (CoreImage `CIQRCodeGenerator`). Scanning uses
AVFoundation `AVCaptureMetadataOutput`. The scanned amount pre-fills
`AmountEntryView`; the user still enters the buy price manually.

## Phases (build history)
1. **Phase 1** — XcodeGen scaffold, Core (Network, Persistence, DI, Theme, L10n,
   Analytics protocols), shared Domain entities. 18 tests, buildable empty app.
2. **Phase 2a** — Portfolio core: DTOs, mapper, CoinRepository (network),
   PortfolioRepository (Core Data with weighted-avg upsert), use cases including
   `GetPortfolioSummaryUseCase`. 53 tests.
3. **Phase 2b** — Portfolio UI: state machine ViewModels, PortfolioView,
   AddCoin search/amount flow. 72 tests, first visible feature.
4. **Phase 3** — CoinDetail + Swift Charts: market_chart endpoint,
   `GetCoinChartUseCase`, CoinDetailView with range selector and line chart.
   91 tests.
5. **Phase 4** — Watchlist: `CDWatchItem`, `WatchlistRepository`,
   `ToggleWatchlistUseCase`, WatchlistView and AddToWatchlist sheet. Also
   structural refactors (`userFacingMessage` → APIError extension; feature
   views take `container: AppContainer`). 115 tests.
6. **Phase 5** — Alerts + Notifications + `BGTaskScheduler`. CRUD use cases,
   `EvaluateAlertsUseCase` (threshold-crossing pure logic),
   `NotificationService` abstraction. 154 tests.
7. **Phase 6** — QR (share + scan). `PortfolioShareCodec`, `QRCodeGenerator`,
   `QRCodeScannerView`. 167 tests.
8. **Phase 7** — Polish: error/L10n pass (`String(localized:)`),
   `InfoPlist.xcstrings`, AccentColor dark variant, perf caches
   (`NumberFormatter`, `CIContext`), `GetWatchlistUseCase` order preservation,
   `CoinDetailViewModel.changeRange` cancellation, AddToWatchlist
   didChange-on-cancel, CoinDetail quick actions, docs and screenshots.
   179 tests, v1 ready.

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
