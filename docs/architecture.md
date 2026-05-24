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
