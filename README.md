# Crypto Portfolio Tracker — iOS

Native SwiftUI crypto portfolio tracker built with Clean Architecture and MVVM.
Portfolio, Watchlist, CoinDetail (with Swift Charts), local price alerts with
recurring/percent/portfolio variants, QR share/scan for portfolio items, and
tr/en localization.

## Requirements
- Xcode 15+ (Swift 5.9+ toolchain), iOS 16+ simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Setup
    cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
    # Optionally set COINGECKO_API_KEY (CoinGecko Demo key) in Config/Secrets.xcconfig
    xcodegen generate
    open CryptoPortfolio.xcodeproj

## Build & test (CLI)
    xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio \
      -destination 'platform=iOS Simulator,name=iPhone 17' test

## Features

- **Portfolio** — add holdings (manual search or QR scan), see live value + P/L
  in your display currency. Pull-to-refresh, swipe-to-delete. Long-press a row
  to share it as a QR code.
- **Watchlist** — star coins you want to follow; live price + 24h change.
- **CoinDetail** — Swift Charts line chart with 24h/7d/30d/1y ranges, market cap,
  24h high/low, and quick actions: add to portfolio, toggle watchlist, create
  alert.
- **Alerts** — price threshold, 24h/7d/30d percent move, portfolio value, and
  portfolio P/L percent. Per-alert recurrence: one-shot, cooldown, or
  on-each-crossing. Evaluated on view appear, pull-to-refresh, and via
  `BGTaskScheduler` background refresh (iOS-throttled, best-effort). Fires
  local `UserNotifications`.
- **Localization** — tr (Türkçe) + en. Camera permission prompt is localized.
- **Theming** — semantic color tokens with dark/light variants.

## Notes
- Price alerts are local and best-effort; a real-time push pipeline is a future
  backend project.
- The free CoinGecko tier has a low rate limit. The app respects it via a
  client-side token-bucket `RateLimiter`.
</content>
</invoke>