# Crypto Portfolio Tracker — Faz 7: Polish (L10n + Theming + CoinDetail Quick Actions + Docs) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finalise v1: localize all user-facing strings (including error messages and camera permission), polish theming, harden a handful of real UX bugs accumulated across phases, add CoinDetail quick actions (add-to-portfolio / toggle-watchlist / create-alert), and refresh README/architecture docs + final screenshots.

**Architecture:** No structural changes. Localization moves inline English literals behind `String(localized:)` / `LocalizedStringKey`. Theming gains an AccentColor dark variant. CoinDetail gets three quick-action surfaces, each delegating to the existing use cases (Add holding via `AmountEntryView` reusing `AddCoinViewModel`; star via `ToggleWatchlistUseCase`; alert via `CreateAlertView` reusing `CreateAlertViewModel`). Performance hygiene caches `NumberFormatter` (per locale + currency code) and `CIContext` (single shared).

**Tech Stack:** Swift 5 mode, SwiftUI, iOS 16+, XCTest. No third-party deps.

Reference spec: `docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` (§5 layers, §9 cross-cutting, §14 Phase 7).

## Existing types this plan consumes (already on `main`)
- All entities, repositories, use cases (Portfolio + Watchlist + CoinDetail + Alerts + QR), DI (`AppContainer`), error mapping (`APIError.userFacingMessage`, `Error.userFacingMessage`), `ViewState<T>`, `CurrencyFormatter`, `Theme`, `QRCodeGenerator`, all view models and views.
- `CryptoPortfolio/Resources/Info.plist` (currently `NSCameraUsageDescription` is Turkish-only).
- `CryptoPortfolio/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` (currently universal/light only).
- `Localizable.xcstrings` has all feature keys; needs error + camera-related additions.
- Test mocks in `CryptoPortfolioTests/Support/Mocks.swift` (4 mocks + 1 spy).
- Latest test count: **167** (after Phase 6 merge).

Build/test commands (simulator "iPhone 17"); `.xcodeproj` is generated and gitignored:
```
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## File Structure (modifications + small additions only)

| File | Responsibility |
| --- | --- |
| `CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift` (modify) | Use `String(localized:)` for messages |
| `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift` (modify) | Localize save-error strings |
| `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift` (modify) | Localize save-error strings |
| `CryptoPortfolio/Resources/Localizable.xcstrings` (modify) | Add error + camera + quick-action keys |
| `CryptoPortfolio/Resources/InfoPlist.xcstrings` (create) | Localized `NSCameraUsageDescription` |
| `CryptoPortfolio/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` (modify) | Add dark appearance variant |
| `CryptoPortfolio/Core/Presentation/CurrencyFormatter.swift` (modify) | Cache `NumberFormatter` per locale+code |
| `CryptoPortfolio/Core/QR/QRCodeGenerator.swift` (modify) | Cache `CIContext` |
| `CryptoPortfolio/Features/Watchlist/Domain/UseCases/GetWatchlistUseCase.swift` (modify) | Preserve `WatchItem.addedAt` insertion order |
| `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift` (modify) | `chartTask: Task<Void, Never>?` cancellation; isWatched + toggleWatchlist |
| `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift` (modify) | Quick-action buttons + sheets |
| `CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistView.swift` (modify) | didChange flag in onDone callback |
| `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift` (modify) | Receive didChange in sheet onDone |
| `README.md` (modify) | Update phases + feature list + screenshot index |
| `docs/architecture.md` (modify) | Reflect Phase 1-7 final architecture |
| `docs/screenshots/` (add) | Final state screenshots |
| `CryptoPortfolioTests/**` | New tests for changed behavior |

---

### Task 1: Localize error messages

**Files:**
- Modify: `CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift`
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift`
- Modify: `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift`
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`
- Test: `CryptoPortfolioTests/Network/APIErrorUserFacingMessageTests.swift`

- [ ] **Step 1: Add error L10n keys to `Localizable.xcstrings`**

Add the following 12 keys inside the top-level `"strings"` object. Keep all existing keys intact; use valid JSON commas. Note: the keys for messages with interpolation use the original literal in `%@`/`%d` form so `String(localized:)` can produce them via `String(format:)`.

```json
    "error.api.rateLimited" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Rate limited. Please try again in a moment." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Hız sınırına takıldık. Lütfen birazdan tekrar dene." } }
      }
    },
    "error.api.networkFormat" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Network error: %@" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Ağ hatası: %@" } }
      }
    },
    "error.api.serverErrorFormat" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Server error (%d)." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Sunucu hatası (%d)." } }
      }
    },
    "error.api.decoding" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Could not parse server response." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Sunucu yanıtı çözümlenemedi." } }
      }
    },
    "error.api.invalidURL" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Invalid request." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Geçersiz istek." } }
      }
    },
    "error.generic" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Something went wrong." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Bir şeyler ters gitti." } }
      }
    },
    "addCoin.error.amountNotPositive" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Amount must be greater than zero." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Miktar sıfırdan büyük olmalı." } }
      }
    },
    "addCoin.error.saveFailed" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Could not save holding." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Varlık kaydedilemedi." } }
      }
    },
    "createAlert.error.priceNotNumber" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Target price is not a number." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Hedef fiyat bir sayı değil." } }
      }
    },
    "createAlert.error.priceNotPositive" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Target price must be greater than zero." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Hedef fiyat sıfırdan büyük olmalı." } }
      }
    },
    "createAlert.error.saveFailed" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Could not save alert." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Alarm kaydedilemedi." } }
      }
    }
```

- [ ] **Step 2: Write a failing test for the localized API error mapping**

Create `CryptoPortfolioTests/Network/APIErrorUserFacingMessageTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class APIErrorUserFacingMessageTests: XCTestCase {

    func test_rateLimited_messageContainsRateWord_inSomeLanguage() {
        let s = APIError.rateLimited.userFacingMessage
        // English ("Rate limited") or Turkish ("Hız sınırına takıldık") — at least one
        // must match. We assert non-empty and that it differs from the generic fallback,
        // which is sufficient to prove the localized lookup is wired (not the empty default).
        XCTAssertFalse(s.isEmpty)
        XCTAssertNotEqual(s, "Something went wrong.")
    }

    func test_transport_includesMessageString() {
        let s = APIError.transport("offline").userFacingMessage
        XCTAssertTrue(s.contains("offline"), "Transport error must interpolate the underlying message")
    }

    func test_requestFailed_includesStatusCode() {
        let s = APIError.requestFailed(statusCode: 503).userFacingMessage
        XCTAssertTrue(s.contains("503"), "Request-failed error must include the status code")
    }

    func test_decoding_returnsNonEmpty() {
        XCTAssertFalse(APIError.decoding("any").userFacingMessage.isEmpty)
    }

    func test_invalidURL_returnsNonEmpty() {
        XCTAssertFalse(APIError.invalidURL.userFacingMessage.isEmpty)
    }

    func test_genericError_fallbackPath() {
        struct OtherError: Error {}
        let s = OtherError().userFacingMessage
        XCTAssertFalse(s.isEmpty)
    }
}
```

- [ ] **Step 3: Run; confirm it still passes (existing behavior matches assertions)**

`cd /Users/efekck/project/crypto-portfolio-tracker && xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/APIErrorUserFacingMessageTests`
Expected: targeted 6/6 pass (the existing English literals satisfy these assertions). This serves as a regression net for the next steps.

- [ ] **Step 4: Replace `APIError+UserFacingMessage.swift` to use `String(localized:)`**

Replace ENTIRE contents of `CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift` with:
```swift
import Foundation

extension APIError {
    /// Localized user-facing message for this error. Falls back to the English text
    /// embedded as the localised key's default value if no string catalog entry is
    /// found.
    var userFacingMessage: String {
        switch self {
        case .rateLimited:
            return String(localized: "error.api.rateLimited",
                          defaultValue: "Rate limited. Please try again in a moment.")
        case .transport(let msg):
            let format = String(localized: "error.api.networkFormat",
                                defaultValue: "Network error: %@")
            return String(format: format, msg)
        case .requestFailed(let code):
            let format = String(localized: "error.api.serverErrorFormat",
                                defaultValue: "Server error (%d).")
            return String(format: format, code)
        case .decoding:
            return String(localized: "error.api.decoding",
                          defaultValue: "Could not parse server response.")
        case .invalidURL:
            return String(localized: "error.api.invalidURL",
                          defaultValue: "Invalid request.")
        }
    }
}

extension Error {
    var userFacingMessage: String {
        (self as? APIError)?.userFacingMessage
            ?? String(localized: "error.generic", defaultValue: "Something went wrong.")
    }
}
```

- [ ] **Step 5: Localize inline error strings in `AddCoinViewModel`**

In `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift`, find the two literals:
```swift
            saveError = "Amount must be greater than zero."
```
and
```swift
            saveError = "Could not save holding."
```
Replace with:
```swift
            saveError = String(localized: "addCoin.error.amountNotPositive",
                               defaultValue: "Amount must be greater than zero.")
```
and
```swift
            saveError = String(localized: "addCoin.error.saveFailed",
                               defaultValue: "Could not save holding.")
```
Leave the rest of the file untouched.

- [ ] **Step 6: Localize inline error strings in `CreateAlertViewModel`**

In `CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift`, find the three literals:
```swift
            saveError = "Target price is not a number."
```
```swift
            saveError = "Target price must be greater than zero."
```
```swift
            saveError = "Could not save alert."
```
Replace with:
```swift
            saveError = String(localized: "createAlert.error.priceNotNumber",
                               defaultValue: "Target price is not a number.")
```
```swift
            saveError = String(localized: "createAlert.error.priceNotPositive",
                               defaultValue: "Target price must be greater than zero.")
```
```swift
            saveError = String(localized: "createAlert.error.saveFailed",
                               defaultValue: "Could not save alert.")
```
Leave the rest of the file untouched.

- [ ] **Step 7: Run targeted + full suite**

```
xcodegen generate
xcodebuild ... test -only-testing:CryptoPortfolioTests/APIErrorUserFacingMessageTests
xcodebuild ... test
```
Expected: targeted 6/6 pass; full suite **173 tests** (167 prior + 6 new), 0 failures. (All existing VM error tests still pass — the messages are unchanged in English; the catalog provides translations.)

- [ ] **Step 8: Commit**

```bash
git add CryptoPortfolio/Core/Network/APIError+UserFacingMessage.swift CryptoPortfolio/Features/Portfolio/Presentation/AddCoinViewModel.swift CryptoPortfolio/Features/Alerts/Presentation/CreateAlertViewModel.swift CryptoPortfolio/Resources/Localizable.xcstrings CryptoPortfolioTests/Network/APIErrorUserFacingMessageTests.swift
git commit -m "feat: localize error messages via String(localized:)"
```

---

### Task 2: Localize `NSCameraUsageDescription` via `InfoPlist.xcstrings`

**Files:**
- Create: `CryptoPortfolio/Resources/InfoPlist.xcstrings`

- [ ] **Step 1: Create `InfoPlist.xcstrings`**

The String Catalog will be compiled to per-locale `InfoPlist.strings` files at build time, overriding the static text in `Info.plist` for localized devices. The static `Info.plist` entry stays as the Turkish fallback.

Create `CryptoPortfolio/Resources/InfoPlist.xcstrings`:
```json
{
  "sourceLanguage" : "tr",
  "strings" : {
    "NSCameraUsageDescription" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Camera access is needed to scan a QR code." } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "QR kodu taramak için kameraya erişim gerekir." } }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 2: Build + full suite**

```
cd /Users/efekck/project/crypto-portfolio-tracker && xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test
```
Expected: `** BUILD SUCCEEDED **` AND `** TEST SUCCEEDED **` with **173 tests** (unchanged), 0 failures. If `xcodegen generate` doesn't pick up the new xcstrings file automatically (because XcodeGen sources path is `CryptoPortfolio`, it should), regenerate and retry.

- [ ] **Step 3: Commit**

```bash
git add CryptoPortfolio/Resources/InfoPlist.xcstrings
git commit -m "feat: localize NSCameraUsageDescription via InfoPlist.xcstrings"
```

---

### Task 3: Theming polish (AccentColor dark variant + small cleanups)

**Files:**
- Modify: `CryptoPortfolio/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Modify: `CryptoPortfolio/Features/CoinDetail/Presentation/RangeSelector.swift` (drop dead `onChange` parameter)
- Modify: `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift` (caller drops the dead arg)
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings` (remove orphan `coinDetail.title` key)

- [ ] **Step 1: Add dark variant to `AccentColor.colorset/Contents.json`**

Replace ENTIRE contents with:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.949", "green" : "0.557", "red" : "0.275" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "1.000", "green" : "0.680", "red" : "0.400" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 2: Drop the dead `onChange` parameter from `RangeSelector`**

Replace ENTIRE contents of `CryptoPortfolio/Features/CoinDetail/Presentation/RangeSelector.swift` with:
```swift
import SwiftUI

struct RangeSelector: View {
    @Binding var selection: PriceRange

    var body: some View {
        Picker("priceRange.label", selection: $selection) {
            ForEach(PriceRange.allCases) { range in
                Text(range.displayLabelKey).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}
```
(The previous `.onChange` modifier was redundant because the Binding setter in `CoinDetailView` already triggers the reload.)

- [ ] **Step 3: Update the caller in `CoinDetailView`**

In `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift`, find:
```swift
            RangeSelector(
                selection: Binding(
                    get: { viewModel.selectedRange },
                    set: { newValue in Task { await viewModel.changeRange(to: newValue) } }
                ),
                onChange: { _ in /* binding setter handles reload */ }
            )
```
Replace with (drop the `onChange:` argument):
```swift
            RangeSelector(
                selection: Binding(
                    get: { viewModel.selectedRange },
                    set: { newValue in Task { await viewModel.changeRange(to: newValue) } }
                )
            )
```
Leave the rest of `CoinDetailView.swift` untouched.

- [ ] **Step 4: Remove the orphan `coinDetail.title` L10n key**

In `CryptoPortfolio/Resources/Localizable.xcstrings`, find and REMOVE the entire entry:
```json
    "coinDetail.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Details" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Detay" } }
      }
    },
```
Keep all other keys intact. Mind the JSON comma — if you delete the last entry in `"strings"`, remove the trailing comma on the prior entry; if you delete an interior entry, just remove the entry's block.

- [ ] **Step 5: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **173 tests** (unchanged), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Resources/Assets.xcassets/AccentColor.colorset/Contents.json CryptoPortfolio/Features/CoinDetail/Presentation/RangeSelector.swift CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift CryptoPortfolio/Resources/Localizable.xcstrings
git commit -m "polish: add AccentColor dark variant; drop RangeSelector dead onChange; remove orphan L10n key"
```

---

### Task 4: Cache `NumberFormatter` (per locale + currency) and `CIContext`

**Files:**
- Modify: `CryptoPortfolio/Core/Presentation/CurrencyFormatter.swift`
- Modify: `CryptoPortfolio/Core/QR/QRCodeGenerator.swift`
- Test: `CryptoPortfolioTests/Core/Presentation/CurrencyFormatterCacheTests.swift`

- [ ] **Step 1: Write the failing test for `CurrencyFormatter` cache identity**

Create `CryptoPortfolioTests/Core/Presentation/CurrencyFormatterCacheTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class CurrencyFormatterCacheTests: XCTestCase {
    func test_repeatedFormatCalls_produceConsistentOutput() {
        let a = CurrencyFormatter.format(1234.5, currency: .usd, locale: Locale(identifier: "en_US"))
        let b = CurrencyFormatter.format(1234.5, currency: .usd, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(a, b)
    }

    func test_differentCurrencies_produceDifferentOutput() {
        let usd = CurrencyFormatter.format(100, currency: .usd, locale: Locale(identifier: "en_US"))
        let try_ = CurrencyFormatter.format(100, currency: .tryLira, locale: Locale(identifier: "tr_TR"))
        XCTAssertNotEqual(usd, try_)
    }

    func test_cacheReturnsSameFormatterInstance() {
        // Internal cache hit: hand the same key twice; the formatter pointer must be the same.
        let f1 = CurrencyFormatter.cachedFormatter(currency: .usd, locale: Locale(identifier: "en_US"))
        let f2 = CurrencyFormatter.cachedFormatter(currency: .usd, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(f1 === f2, "Cache must return the same formatter instance for identical key")
    }
}
```

- [ ] **Step 2: Replace `CurrencyFormatter.swift` to use a cache**

Replace ENTIRE contents of `CryptoPortfolio/Core/Presentation/CurrencyFormatter.swift` with:
```swift
import Foundation

/// Locale-aware formatters for monetary and percent display. NumberFormatter is
/// expensive to construct; this type caches one per (locale identifier, currency code)
/// pair behind a serial queue.
enum CurrencyFormatter {

    // MARK: - Public API

    static func format(_ value: Double, currency: Currency, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(currency: currency, locale: locale)
        return formatter.string(from: NSNumber(value: value))
            ?? "\(currency.symbol)\(String(format: "%.2f", value))"
    }

    static func formatPercent(_ value: Double, locale: Locale = .current) -> String {
        let formatter = cachedDecimalFormatter(locale: locale)
        let abs = formatter.string(from: NSNumber(value: Swift.abs(value))) ?? "0.00"
        let sign = value < 0 ? "-" : "+"
        return "\(sign)\(abs)%"
    }

    // MARK: - Cache (exposed for tests)

    private static var currencyCache: [String: NumberFormatter] = [:]
    private static var decimalCache: [String: NumberFormatter] = [:]
    private static let queue = DispatchQueue(label: "CurrencyFormatter.cache")

    static func cachedFormatter(currency: Currency, locale: Locale) -> NumberFormatter {
        queue.sync {
            let key = "\(locale.identifier)-\(currency.code.uppercased())"
            if let cached = currencyCache[key] { return cached }
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            formatter.currencyCode = currency.code.uppercased()
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            currencyCache[key] = formatter
            return formatter
        }
    }

    static func cachedDecimalFormatter(locale: Locale) -> NumberFormatter {
        queue.sync {
            let key = locale.identifier
            if let cached = decimalCache[key] { return cached }
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            decimalCache[key] = formatter
            return formatter
        }
    }
}
```

- [ ] **Step 3: Update `QRCodeGenerator.swift` to cache `CIContext`**

Replace ENTIRE contents of `CryptoPortfolio/Core/QR/QRCodeGenerator.swift` with:
```swift
import UIKit
import CoreImage

/// Produces a `UIImage` from a string using CoreImage's QR code filter.
/// Returns `nil` for empty strings or generation failure.
enum QRCodeGenerator {
    /// `CIContext` construction is documented as expensive; share one for all callers.
    private static let context = CIContext()

    static func generate(text: String, size: CGFloat = 240) -> UIImage? {
        guard !text.isEmpty,
              let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter?.outputImage else { return nil }
        let scale = max(1, size / ciImage.extent.width)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
```

- [ ] **Step 4: Run targeted + full suite**

```
xcodegen generate
xcodebuild ... test -only-testing:CryptoPortfolioTests/CurrencyFormatterCacheTests
xcodebuild ... test
```
Expected: CurrencyFormatterCacheTests 3/3; full suite **176 tests** (173 prior + 3 new), 0 failures. The existing `CurrencyFormatterTests` (3 tests) keep passing because the public API is unchanged.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Core/Presentation/CurrencyFormatter.swift CryptoPortfolio/Core/QR/QRCodeGenerator.swift CryptoPortfolioTests/Core/Presentation/CurrencyFormatterCacheTests.swift
git commit -m "perf: cache NumberFormatter (per locale+code) and CIContext"
```

---

### Task 5: `GetWatchlistUseCase` preserves `WatchItem.addedAt` order

**Files:**
- Modify: `CryptoPortfolio/Features/Watchlist/Domain/UseCases/GetWatchlistUseCase.swift`
- Modify: `CryptoPortfolioTests/Watchlist/Domain/WatchlistUseCasesTests.swift` (add order test)

- [ ] **Step 1: Write the failing test**

APPEND to the existing `WatchlistUseCasesTests` class:
```swift
    func test_getWatchlist_preservesAddedAtOrder_evenWhenAPIReturnsDifferently() async throws {
        let watchRepo = MockWatchlistRepository()
        // Add A then B; MockWatchlistRepository.items() sorts by addedAt ascending.
        try watchRepo.add(coinId: "alpha")
        try await Task.sleep(nanoseconds: 1_000_000)
        try watchRepo.add(coinId: "beta")

        let coinRepo = MockCoinRepository()
        // Markets returns the coins in the *reverse* order to simulate API ordering.
        coinRepo.marketsResult = [
            Coin(id: "beta", symbol: "b", name: "Beta", currentPrice: 1),
            Coin(id: "alpha", symbol: "a", name: "Alpha", currentPrice: 1)
        ]
        let sut = GetWatchlistUseCase(watchlistRepository: watchRepo, coinRepository: coinRepo)

        let result = try await sut(currency: .usd)

        XCTAssertEqual(result.map(\.id), ["alpha", "beta"],
                       "Result must follow WatchItem.addedAt order, not the API order")
    }
```

- [ ] **Step 2: Run; confirm FAIL**

`cd /Users/efekck/project/crypto-portfolio-tracker && xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistUseCasesTests`
Expected: the new test fails because the use case currently returns whatever the markets call returns (`[beta, alpha]` here), not `[alpha, beta]`.

- [ ] **Step 3: Update the use case**

Replace ENTIRE contents of `CryptoPortfolio/Features/Watchlist/Domain/UseCases/GetWatchlistUseCase.swift` with:
```swift
import Foundation

struct GetWatchlistUseCase {
    let watchlistRepository: WatchlistRepository
    let coinRepository: CoinRepository

    func callAsFunction(currency: Currency) async throws -> [Coin] {
        let items = try watchlistRepository.items()
        guard !items.isEmpty else { return [] }
        let ids = items.map(\.coinId)
        let coins = try await coinRepository.markets(ids: ids, currency: currency)
        let coinsById = Dictionary(coins.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Preserve the original `WatchItem.addedAt` order returned by the repo.
        return ids.compactMap { coinsById[$0] }
    }
}
```

- [ ] **Step 4: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/WatchlistUseCasesTests
xcodebuild ... test
```
Expected: WatchlistUseCasesTests 5/5 (4 prior + 1 new); full suite **177 tests** (176 prior + 1 new), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Features/Watchlist/Domain/UseCases/GetWatchlistUseCase.swift CryptoPortfolioTests/Watchlist/Domain/WatchlistUseCasesTests.swift
git commit -m "fix: GetWatchlistUseCase preserves WatchItem.addedAt order"
```

---

### Task 6: `CoinDetailViewModel.changeRange` cancels the previous chart task

**Files:**
- Modify: `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift`
- Modify: `CryptoPortfolioTests/CoinDetail/Presentation/CoinDetailViewModelTests.swift` (add cancellation test)

- [ ] **Step 1: Update `CoinDetailViewModel`**

Add a `chartTask: Task<Void, Never>?` property and rewrite `changeRange` to cancel the previous one. Find the existing `changeRange` method:
```swift
    func changeRange(to range: PriceRange) async {
        selectedRange = range
        await loadChart()
    }
```
Replace with two changes:

A) Add the stored property INSIDE the class body (alongside other stored properties, before `init`):
```swift
    private var chartTask: Task<Void, Never>?
```

B) Replace the `changeRange` method body with:
```swift
    func changeRange(to range: PriceRange) async {
        selectedRange = range
        chartTask?.cancel()
        let task = Task { [weak self] in
            await self?.loadChart()
        }
        chartTask = task
        await task.value
    }
```
Do NOT change `loadChart()` itself — Swift's `Task.isCancelled` cooperative cancellation is sufficient since the use case awaits the network call. The existing `loadChart()` will run to completion if no cancellation occurs.

- [ ] **Step 2: Append a test exercising cancellation**

APPEND to the existing `CoinDetailViewModelTests`:
```swift
    func test_changeRange_cancelsPreviousChartTask_andOnlyAppliesLatest() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        let firstPoints = [ChartPoint(id: 1, date: Date(timeIntervalSince1970: 0), price: 100)]
        let secondPoints = [ChartPoint(id: 2, date: Date(timeIntervalSince1970: 60), price: 200)]
        let (sut, repo) = makeSUT(coin: coin, points: firstPoints)
        await sut.loadAll()

        // Trigger rapid range switches. Each `await` allows the task to run.
        repo.chartResult = firstPoints
        async let r1: Void = sut.changeRange(to: .d7)
        repo.chartResult = secondPoints
        async let r2: Void = sut.changeRange(to: .d30)
        _ = await (r1, r2)

        // Whatever ran last must win.
        XCTAssertEqual(sut.selectedRange, .d30)
        if case .loaded(let pts) = sut.chartState {
            XCTAssertEqual(pts.first?.price, 200, "Latest range request must apply")
        } else {
            XCTFail("Expected chart .loaded after final range change")
        }
    }
```

- [ ] **Step 3: Run targeted + full suite**

```
xcodegen generate
xcodebuild ... test -only-testing:CryptoPortfolioTests/CoinDetailViewModelTests
xcodebuild ... test
```
Expected: CoinDetailViewModelTests 6/6 (5 prior + 1 new); full suite **178 tests** (177 prior + 1 new), 0 failures.

If the new test is flaky on this serialised actor model, that's a real finding — report it. The cancellation guard is straightforward; on @MainActor every state update is serialised, so the test is deterministic.

- [ ] **Step 4: Commit**

```bash
git add CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift CryptoPortfolioTests/CoinDetail/Presentation/CoinDetailViewModelTests.swift
git commit -m "fix: CoinDetailViewModel.changeRange cancels the previous chart task"
```

---

### Task 7: `AddToWatchlistView` Cancel uses a didChange flag

**Files:**
- Modify: `CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistView.swift` (track + signal didChange)
- Modify: `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift` (only reload on didChange)

- [ ] **Step 1: Update `AddToWatchlistView`**

In `CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistView.swift`, change the closure type and Cancel/toggle paths. Find:
```swift
    let onDone: () -> Void
```
Replace with:
```swift
    let onDone: (_ didChange: Bool) -> Void
```
Find:
```swift
    init(container: AppContainer, onDone: @escaping () -> Void) {
```
Replace with:
```swift
    init(container: AppContainer, onDone: @escaping (Bool) -> Void) {
```
Add a `@State` flag inside the struct (right after the `@StateObject` line):
```swift
    @State private var didChange = false
```
Find the Cancel button:
```swift
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone() }
                    }
                }
```
Replace with:
```swift
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone(didChange) }
                    }
                }
```
Find the toggle button inside the `List(coins)`:
```swift
                Button {
                    Task { await viewModel.toggle(coinId: coin.id) }
                } label: {
```
Replace with:
```swift
                Button {
                    Task {
                        await viewModel.toggle(coinId: coin.id)
                        didChange = true
                    }
                } label: {
```
Leave everything else in the file untouched.

- [ ] **Step 2: Update `WatchlistView` callsite**

In `CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift`, find the sheet:
```swift
                .sheet(isPresented: $isShowingAddSheet) {
                    AddToWatchlistView(container: container) {
                        isShowingAddSheet = false
                        Task { await viewModel.load() }
                    }
                }
```
Replace with:
```swift
                .sheet(isPresented: $isShowingAddSheet) {
                    AddToWatchlistView(container: container) { didChange in
                        isShowingAddSheet = false
                        if didChange { Task { await viewModel.load() } }
                    }
                }
```

- [ ] **Step 3: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **178 tests** (unchanged — UI change, no test count change), 0 failures.

- [ ] **Step 4: Commit**

```bash
git add CryptoPortfolio/Features/Watchlist/Presentation/AddToWatchlistView.swift CryptoPortfolio/Features/Watchlist/Presentation/WatchlistView.swift
git commit -m "polish: AddToWatchlistView Cancel only triggers reload on didChange"
```

---

### Task 8: CoinDetail quick actions (Add-to-portfolio + Watchlist toggle + Create-alert)

The biggest task in this phase: CoinDetail gains three quick actions. The ViewModel grows an `isWatched: Bool` published property + `toggleWatchlist()` method (idempotent local refresh); the View gains a quick-action row under the header.

**Files:**
- Modify: `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift`
- Modify: `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift`
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`
- Modify: `CryptoPortfolioTests/CoinDetail/Presentation/CoinDetailViewModelTests.swift`

- [ ] **Step 1: Add L10n keys**

Add inside `"strings"`:
```json
    "coinDetail.action.addToPortfolio" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Add to portfolio" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Portföye ekle" } }
      }
    },
    "coinDetail.action.watchlistAdd" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Watch" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "İzle" } }
      }
    },
    "coinDetail.action.watchlistRemove" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Unwatch" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "İzlemeyi bırak" } }
      }
    },
    "coinDetail.action.createAlert" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Create alert" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Alarm oluştur" } }
      }
    }
```

- [ ] **Step 2: Write a failing test for the watchlist toggle**

APPEND to `CoinDetailViewModelTests`:
```swift
    func test_toggleWatchlist_addsAndThenRemoves_andUpdatesIsWatched() async {
        // Build a SUT with explicit watchlist dependencies (the existing makeSUT does not
        // wire these; construct directly).
        let alertRepo = MockAlertRepository()
        _ = alertRepo // unused; kept to mirror future tests
        let watchRepo = MockWatchlistRepository()
        let coinRepo = MockCoinRepository()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000)
        coinRepo.marketsResult = [coin]
        let vm = CoinDetailViewModel(
            coinId: "bitcoin",
            currency: .usd,
            getCoinMarket: GetCoinMarketUseCase(coinRepository: coinRepo),
            getCoinChart: GetCoinChartUseCase(coinRepository: coinRepo),
            toggleWatchlist: ToggleWatchlistUseCase(watchlistRepository: watchRepo),
            watchlistRepository: watchRepo
        )
        await vm.refreshIsWatched()
        XCTAssertFalse(vm.isWatched)

        await vm.toggleWatchlist()
        XCTAssertTrue(vm.isWatched)
        XCTAssertTrue(try watchRepo.isWatched(coinId: "bitcoin"))

        await vm.toggleWatchlist()
        XCTAssertFalse(vm.isWatched)
        XCTAssertFalse(try watchRepo.isWatched(coinId: "bitcoin"))
    }
```

This test will fail to compile because `CoinDetailViewModel.init` doesn't take `toggleWatchlist:` / `watchlistRepository:` yet. Step 3 fixes that.

- [ ] **Step 3: Update `CoinDetailViewModel`**

Replace ENTIRE contents of `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift` with:
```swift
import Foundation

@MainActor
final class CoinDetailViewModel: ObservableObject {
    @Published private(set) var headerState: ViewState<Coin> = .loading
    @Published private(set) var chartState: ViewState<[ChartPoint]> = .loading
    @Published private(set) var selectedRange: PriceRange = .h24
    @Published private(set) var isWatched: Bool = false

    let coinId: String
    let currency: Currency

    private let getCoinMarket: GetCoinMarketUseCase
    private let getCoinChart: GetCoinChartUseCase
    private let toggleWatchlistUseCase: ToggleWatchlistUseCase?
    private let watchlistRepository: WatchlistRepository?

    private var chartTask: Task<Void, Never>?

    init(coinId: String,
         currency: Currency,
         getCoinMarket: GetCoinMarketUseCase,
         getCoinChart: GetCoinChartUseCase,
         toggleWatchlist: ToggleWatchlistUseCase? = nil,
         watchlistRepository: WatchlistRepository? = nil) {
        self.coinId = coinId
        self.currency = currency
        self.getCoinMarket = getCoinMarket
        self.getCoinChart = getCoinChart
        self.toggleWatchlistUseCase = toggleWatchlist
        self.watchlistRepository = watchlistRepository
    }

    func loadAll() async {
        async let header: () = loadHeader()
        async let chart: () = loadChart()
        async let watch: () = refreshIsWatched()
        _ = await (header, chart, watch)
    }

    func loadHeader() async {
        headerState = .loading
        do {
            if let coin = try await getCoinMarket(coinId: coinId, currency: currency) {
                headerState = .loaded(coin)
            } else {
                headerState = .error(String(localized: "error.generic",
                                            defaultValue: "Something went wrong."))
            }
        } catch {
            headerState = .error(error.userFacingMessage)
        }
    }

    func loadChart() async {
        chartState = .loading
        do {
            let points = try await getCoinChart(coinId: coinId, range: selectedRange, currency: currency)
            chartState = .loaded(points)
        } catch {
            chartState = .error(error.userFacingMessage)
        }
    }

    func changeRange(to range: PriceRange) async {
        selectedRange = range
        chartTask?.cancel()
        let task = Task { [weak self] in
            await self?.loadChart()
        }
        chartTask = task
        await task.value
    }

    func refreshIsWatched() async {
        guard let repo = watchlistRepository else { return }
        isWatched = (try? repo.isWatched(coinId: coinId)) ?? false
    }

    func toggleWatchlist() async {
        guard let useCase = toggleWatchlistUseCase else { return }
        try? useCase(coinId: coinId)
        await refreshIsWatched()
    }
}
```

NOTE: this changes `init` so that `toggleWatchlist` and `watchlistRepository` are optional with defaults nil. All existing `CoinDetailView` callsites that pass `getCoinMarket: …, getCoinChart: …` continue to compile (they pick up nil defaults), so the watchlist quick action only works where the container is actually wired through.

- [ ] **Step 4: Update `CoinDetailView`**

Replace ENTIRE contents of `CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift` with the version that wires the container into the VM and adds the quick-action row:
```swift
import SwiftUI

struct CoinDetailView: View {
    @StateObject private var viewModel: CoinDetailViewModel
    let coinName: String
    private let container: AppContainer

    @State private var addingHolding: Coin?
    @State private var creatingAlertFor: Coin?

    init(coinId: String,
         coinName: String,
         currency: Currency,
         container: AppContainer) {
        self.coinName = coinName
        self.container = container
        _viewModel = StateObject(wrappedValue: CoinDetailViewModel(
            coinId: coinId,
            currency: currency,
            getCoinMarket: container.makeGetCoinMarketUseCase(),
            getCoinChart: container.makeGetCoinChartUseCase(),
            toggleWatchlist: container.makeToggleWatchlistUseCase(),
            watchlistRepository: container.watchlistRepository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                quickActions
                rangeAndChartSection
                statsSection
            }
            .padding()
        }
        .navigationTitle(coinName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAll() }
        .sheet(item: $addingHolding) { coin in
            NavigationStack {
                AmountEntryView(
                    coin: coin,
                    viewModel: AddCoinViewModel(
                        searchCoins: container.makeSearchCoinsUseCase(),
                        addHolding: container.makeAddHoldingUseCase()
                    )
                ) { _ in addingHolding = nil }
            }
        }
        .sheet(item: $creatingAlertFor) { _ in
            CreateAlertView(container: container) { _ in
                creatingAlertFor = nil
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        switch viewModel.headerState {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .empty:
            EmptyView()
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.loadHeader() } }
                .frame(minHeight: 120)
        case .loaded(let coin):
            CoinDetailHeaderView(coin: coin, currency: viewModel.currency)
        }
    }

    @ViewBuilder
    private var quickActions: some View {
        if case .loaded(let coin) = viewModel.headerState {
            HStack(spacing: 12) {
                Button {
                    addingHolding = coin
                } label: {
                    Label("coinDetail.action.addToPortfolio", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button {
                    Task { await viewModel.toggleWatchlist() }
                } label: {
                    Label(viewModel.isWatched ? "coinDetail.action.watchlistRemove"
                                              : "coinDetail.action.watchlistAdd",
                          systemImage: viewModel.isWatched ? "star.slash.fill" : "star.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isWatched ? .secondary : Theme.accent)

                Button {
                    creatingAlertFor = coin
                } label: {
                    Label("coinDetail.action.createAlert", systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.medium))
        }
    }

    private var rangeAndChartSection: some View {
        VStack(spacing: 12) {
            RangeSelector(
                selection: Binding(
                    get: { viewModel.selectedRange },
                    set: { newValue in Task { await viewModel.changeRange(to: newValue) } }
                )
            )
            chartContent
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        switch viewModel.chartState {
        case .loading:
            ProgressView().frame(height: 220)
        case .empty:
            Text("—").foregroundStyle(.secondary).frame(height: 220)
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.loadChart() } }
                .frame(minHeight: 220)
        case .loaded(let points):
            PriceChartView(points: points)
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if case .loaded(let coin) = viewModel.headerState {
            VStack(alignment: .leading, spacing: 8) {
                Text("coinDetail.stats.title")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                CoinStatsView(coin: coin, currency: viewModel.currency)
            }
        }
    }
}
```

NOTE: `Coin` is consumed as `Identifiable` by `.sheet(item:)`. `Coin` already conforms to Identifiable (its `id: String` field). The `Coin?` state vars work.

- [ ] **Step 5: Run targeted + full suite**

```
xcodegen generate
xcodebuild ... test -only-testing:CryptoPortfolioTests/CoinDetailViewModelTests
xcodebuild ... test
```
Expected: CoinDetailViewModelTests 7/7 (6 prior + 1 new); full suite **179 tests** (178 prior + 1 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailViewModel.swift CryptoPortfolio/Features/CoinDetail/Presentation/CoinDetailView.swift CryptoPortfolio/Resources/Localizable.xcstrings CryptoPortfolioTests/CoinDetail/Presentation/CoinDetailViewModelTests.swift
git commit -m "feat: add CoinDetail quick actions (add-to-portfolio, watchlist toggle, create alert)"
```

---

### Task 9: README + architecture.md polish + final screenshots

**Files:**
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Create: `docs/screenshots/v1-portfolio-empty.png` (best-effort)

- [ ] **Step 1: Replace `README.md`**

```markdown
# Crypto Portfolio Tracker — iOS

Native SwiftUI crypto portfolio tracker built with Clean Architecture and MVVM. v1
ships Portfolio, Watchlist, CoinDetail (with Swift Charts), local price Alerts,
QR share/scan for portfolio items, and tr/en localization.

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

## Features (v1)

- **Portfolio** — add holdings (manual search or QR scan), see live value + P/L
  in your display currency. Pull-to-refresh, swipe-to-delete. Long-press a row
  to share it as a QR code.
- **Watchlist** — star coins you want to follow; live price + 24h change.
- **CoinDetail** — Swift Charts line chart with 24h/7d/30d/1y ranges, market cap,
  24h high/low, and quick actions: add to portfolio, toggle watchlist, create
  alert.
- **Alerts** — local price alerts (above/below), evaluated on view appear,
  pull-to-refresh, and via `BGTaskScheduler` background refresh
  (iOS-throttled, best-effort). Fires local `UserNotifications`.
- **Localization** — tr (Türkçe) + en. Camera permission prompt is localized.
- **Theming** — semantic color tokens with dark/light variants.

## Architecture
See `docs/architecture.md` for the layer overview, dependency direction, and the
phase-by-phase build history.

## Notes
- Price alerts are local and best-effort; a real-time push pipeline is a future
  backend project.
- The free CoinGecko tier has a low rate limit. The app respects it via a
  client-side token-bucket `RateLimiter`.
```

- [ ] **Step 2: Replace `docs/architecture.md`**

```markdown
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
```

- [ ] **Step 3: Launch + capture a final screenshot (best-effort)**

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
xcrun simctl io booted screenshot docs/screenshots/v1-portfolio-empty.png
file docs/screenshots/v1-portfolio-empty.png
```
If `xcrun simctl io booted screenshot` fails entirely (no PNG produced), skip the screenshot and continue.

- [ ] **Step 4: Build + full suite (regression net)**

```
xcodegen generate
xcodebuild ... test
```
Expected: `** TEST SUCCEEDED **` with **179 tests** (unchanged from Task 8), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/architecture.md docs/screenshots/
git status
git commit -m "docs: README + architecture refresh; v1 launch screenshot"
```
Verify `git status` shows ONLY these paths. `build/`, `.xcodeproj/`, `Config/Secrets.xcconfig` must NOT be staged.

---

## Self-Review

**1. Spec coverage (§14 Phase 7):**
- L10n pass (tr/en) for error messages and inline VM error strings → Task 1 ✅
- L10n pass for camera permission (`NSCameraUsageDescription`) → Task 2 ✅
- Theming polish (AccentColor dark + small cleanups) → Task 3 ✅
- README + architecture docs updated → Task 9 ✅
- Final screenshots → Task 9 ✅

**Deferred-review-items addressed in this phase:**
- `NumberFormatter` cache + `CIContext` cache → Task 4 ✅
- `GetWatchlistUseCase` re-sort (preserves `WatchItem.addedAt` order) → Task 5 ✅
- `CoinDetailViewModel.changeRange` Task cancellation → Task 6 ✅
- `AddToWatchlistView` Cancel didChange flag → Task 7 ✅
- `RangeSelector.onChange` dead parameter cleanup → Task 3 ✅
- Orphan `coinDetail.title` L10n key → Task 3 ✅
- CoinDetail quick actions (add to portfolio / watchlist / alert) → Task 8 ✅
- `ScanQRSheet` error auto-dismiss / minor styling — left as polish backlog (does not affect v1 correctness).
- HTTPClient/AnalyticsService Sendable, CrashReporter user-context, release signing config — out of v1 scope (Swift 6 / Firebase / deployment future projects).

**2. Placeholder scan:** No "TBD"/"TODO"/"add validation" placeholders. Every code step has complete code; every command has an expected output and a test count progression. The Task 9 screenshot step is best-effort and clearly marked.

**3. Type consistency:**
- `String(localized: <key>, defaultValue: <fallback>)` consistently used across Tasks 1, 6 (one call) — signature is `String(localized: String.LocalizationValue, defaultValue: String.LocalizationValue?)`, returns `String`. iOS 15+.
- `APIError.userFacingMessage` / `Error.userFacingMessage` String-returning signatures unchanged — VM `state = .error(error.userFacingMessage)` call sites stay byte-identical.
- `CoinDetailViewModel.init` adds `toggleWatchlist: ToggleWatchlistUseCase? = nil, watchlistRepository: WatchlistRepository? = nil` with default nil — all existing callers (the Phase 3 test suite that still constructs the VM with the older 4-arg form) compile unchanged; the new VM test (Task 8) explicitly passes both.
- `CoinDetailView.init(coinId:coinName:currency:container:)` shape unchanged from Phase 4. The internal `AddCoinViewModel` construction for the `.sheet(item: $addingHolding)` reuses existing factories.
- `AddToWatchlistView` `onDone` callback type changes from `() -> Void` to `(Bool) -> Void`. The single callsite in `WatchlistView` is updated in Task 7 — no other consumers exist (grep can confirm).
- L10n keys consistent: `error.api.*`, `addCoin.error.*`, `createAlert.error.*`, `coinDetail.action.*` follow `feature.area.element` convention.
- Test count progression: 167 (start) → 173 (T1: +6) → 173 (T2) → 173 (T3) → 176 (T4: +3) → 177 (T5: +1) → 178 (T6: +1) → 178 (T7) → 179 (T8: +1) → 179 (T9). ✅

No issues found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-01-crypto-portfolio-ios-phase7-polish.md`.
