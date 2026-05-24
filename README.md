# Crypto Portfolio Tracker — iOS

Native SwiftUI crypto portfolio tracker (Clean Architecture, MVVM). See
`docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` for the full design.

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

## Notes
- Price alerts are local and best-effort (background refresh), not guaranteed real-time
  — a push backend would be a separate project. See `docs/architecture.md`.
