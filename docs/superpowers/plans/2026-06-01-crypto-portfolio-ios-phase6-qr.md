# Crypto Portfolio Tracker — Faz 6: QR (Share + Scan) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a portfolio-share QR code (`cptp://v1?coin=<coinId>&amount=<decimal>`) for any holding from PortfolioView, and scan one from AddCoinView to pre-fill the AmountEntryView's amount field. No third-party deps.

**Architecture:** Pure-Swift `PortfolioShareCodec` for encode/decode (the testable core). `QRCodeGenerator` wraps CoreImage's `CIQRCodeGenerator` (testable: produces UIImage). `QRCodeScannerView` wraps `AVCaptureSession` + `AVCaptureMetadataOutput` inside a `UIViewControllerRepresentable` (OS-coupled — build verification only). `ShareQRView` is presented from a HoldingRow `.contextMenu`. `ScanQRSheet` is presented from an AddCoinView toolbar button; on detect it dismisses and a follow-up `.sheet(item:)` presents AmountEntryView with the parsed amount prefilled.

**Tech Stack:** Swift 5 mode, SwiftUI, iOS 16+, CoreImage (`CIFilter.qrCodeGenerator`), AVFoundation, XCTest. No third-party deps.

Reference spec: `docs/superpowers/specs/2026-05-24-crypto-portfolio-ios-design.md` (§11 QR format).

## Existing types this plan consumes (already on `main`)
- Domain entities: `Coin`, `Holding`, `Currency`, `PortfolioSummary`, `HoldingValuation`, `PriceAlert`.
- Repositories/use cases: full Portfolio + Watchlist + CoinDetail + Alerts sets.
- DI: `AppContainer` with `evaluateAndNotify`, all `make*UseCase()` factories.
- Presentation: `ViewState<T>`, `CurrencyFormatter`, all view models, `PortfolioView` (currently has `loadedList` with `HoldingRow` inside a `NavigationLink`; `+` button presents `AddCoinView` sheet), `AddCoinView` (currently has `.searchable` + `.onSubmit(of: .search)` + cancellation toolbar). `AmountEntryView` currently has `@State private var amountText: String = ""` initialised at declaration.
- `Info.plist` already has `NSCameraUsageDescription` (Turkish): "QR kodu taramak için kameraya erişim gerekir." (added in Phase 1).
- `Localizable.xcstrings` has `common.cancel`, `common.delete`, `common.retry`, plus `addCoin.*`, `portfolio.*`, etc.

Build/test commands (simulator "iPhone 17"); `.xcodeproj` is generated and gitignored:
```
xcodegen generate
xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## File Structure

| File | Responsibility |
| --- | --- |
| `CryptoPortfolio/Domain/Entities/PortfolioShareCode.swift` | `PortfolioShareCode(coinId:amount:)` + Identifiable for sheet(item:) |
| `CryptoPortfolio/Core/QR/PortfolioShareCodec.swift` | Pure URL encode/decode + `PortfolioShareCodecError` |
| `CryptoPortfolio/Core/QR/QRCodeGenerator.swift` | `static generate(text:size:) -> UIImage?` |
| `CryptoPortfolio/Core/QR/QRCodeScannerView.swift` | UIViewControllerRepresentable over `AVCaptureSession` |
| `CryptoPortfolio/Features/QRImport/Presentation/ScanQRSheet.swift` | Scanner sheet w/ Cancel + error toast |
| `CryptoPortfolio/Features/Portfolio/Presentation/ShareQRView.swift` | QR + URL + ShareLink in a sheet |
| `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift` (modify) | HoldingRow `.contextMenu` Share QR → `.sheet(item:)` |
| `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift` (modify) | Toolbar Scan QR button → `.sheet(isPresented:)` ScanQRSheet → `.sheet(item:)` AmountEntryView with prefill |
| `CryptoPortfolio/Features/Portfolio/Presentation/AmountEntryView.swift` (modify) | Init accepts `prefillAmount: Double?` |
| `CryptoPortfolio/Resources/Localizable.xcstrings` (modify) | `qr.*` keys |
| `CryptoPortfolioTests/**` | Mirror tests for the testable core |
| `docs/screenshots/phase6-share-qr.png` | Visual verification (best-effort, share-side; scanner needs hardware) |

---

### Task 1: `PortfolioShareCode` entity + `PortfolioShareCodec` (encode / decode)

**Files:**
- Create: `CryptoPortfolio/Domain/Entities/PortfolioShareCode.swift`
- Create: `CryptoPortfolio/Core/QR/PortfolioShareCodec.swift`
- Test: `CryptoPortfolioTests/QR/PortfolioShareCodecTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/QR/PortfolioShareCodecTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class PortfolioShareCodecTests: XCTestCase {

    func test_encode_producesExpectedURLShape() {
        let code = PortfolioShareCode(coinId: "bitcoin", amount: 0.5)
        let s = PortfolioShareCodec.encode(code)
        // The exact ordering of query items may vary, but both must appear.
        XCTAssertTrue(s.hasPrefix("cptp://v1?"))
        XCTAssertTrue(s.contains("coin=bitcoin"))
        XCTAssertTrue(s.contains("amount=0.5"))
    }

    func test_encodeDecodeRoundTrip() throws {
        let original = PortfolioShareCode(coinId: "ethereum", amount: 12.345)
        let s = PortfolioShareCodec.encode(original)

        let decoded = try PortfolioShareCodec.decode(s)

        XCTAssertEqual(decoded, original)
    }

    func test_decode_rejectsWrongScheme() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("https://v1?coin=bitcoin&amount=1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .invalidScheme)
        }
    }

    func test_decode_rejectsWrongVersion() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v2?coin=bitcoin&amount=1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .invalidVersion)
        }
    }

    func test_decode_rejectsMissingCoin() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?amount=1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingCoin)
        }
    }

    func test_decode_rejectsMissingAmount() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
    }

    func test_decode_rejectsNonPositiveAmount() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin&amount=0")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin&amount=-1")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
    }

    func test_decode_rejectsUnparseableAmount() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("cptp://v1?coin=bitcoin&amount=abc")) { error in
            XCTAssertEqual(error as? PortfolioShareCodecError, .missingOrInvalidAmount)
        }
    }

    func test_decode_rejectsMalformedURL() {
        XCTAssertThrowsError(try PortfolioShareCodec.decode("not a url at all!! ")) { error in
            // URLComponents tolerates many strings, so the actual failure may be invalidScheme
            // (host/scheme nil) instead of malformedURL. Accept either.
            let err = error as? PortfolioShareCodecError
            XCTAssertTrue(err == .malformedURL || err == .invalidScheme,
                          "Expected malformedURL or invalidScheme, got \(String(describing: err))")
        }
    }

    func test_portfolioShareCode_isIdentifiableByCoinIdAndAmount() {
        let a = PortfolioShareCode(coinId: "bitcoin", amount: 1)
        let b = PortfolioShareCode(coinId: "bitcoin", amount: 1)
        let c = PortfolioShareCode(coinId: "bitcoin", amount: 2)
        XCTAssertEqual(a.id, b.id)
        XCTAssertNotEqual(a.id, c.id)
    }
}
```

- [ ] **Step 2: Run; confirm FAIL to compile**

`cd /Users/efekck/project/crypto-portfolio-tracker && xcodegen generate && xcodebuild -project CryptoPortfolio.xcodeproj -scheme CryptoPortfolio -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:CryptoPortfolioTests/PortfolioShareCodecTests`
Expected: `cannot find 'PortfolioShareCode' / 'PortfolioShareCodec' / 'PortfolioShareCodecError' in scope`.

- [ ] **Step 3: Create the entity**

`CryptoPortfolio/Domain/Entities/PortfolioShareCode.swift`:
```swift
import Foundation

/// A QR-shareable portfolio item: a coin id + an amount.
struct PortfolioShareCode: Identifiable, Equatable {
    let coinId: String
    let amount: Double

    /// Stable identifier so SwiftUI `.sheet(item:)` can present the right sheet.
    var id: String { "\(coinId)-\(amount)" }
}
```

- [ ] **Step 4: Create the codec**

`CryptoPortfolio/Core/QR/PortfolioShareCodec.swift`:
```swift
import Foundation

enum PortfolioShareCodecError: Error, Equatable {
    case malformedURL
    case invalidScheme
    case invalidVersion
    case missingCoin
    case missingOrInvalidAmount
}

/// Encodes/decodes `cptp://v1?coin=<id>&amount=<decimal>` URLs.
enum PortfolioShareCodec {
    static let scheme = "cptp"
    static let version = "v1"

    static func encode(_ code: PortfolioShareCode) -> String {
        var components = URLComponents()
        components.scheme = scheme
        components.host = version
        components.queryItems = [
            URLQueryItem(name: "coin", value: code.coinId),
            URLQueryItem(name: "amount", value: String(code.amount))
        ]
        return components.url?.absoluteString
            ?? "\(scheme)://\(version)?coin=\(code.coinId)&amount=\(code.amount)"
    }

    static func decode(_ raw: String) throws -> PortfolioShareCode {
        guard let components = URLComponents(string: raw) else {
            throw PortfolioShareCodecError.malformedURL
        }
        guard components.scheme == scheme else { throw PortfolioShareCodecError.invalidScheme }
        guard components.host == version else { throw PortfolioShareCodecError.invalidVersion }

        let items = (components.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value ?? ""
        }
        guard let coin = items["coin"], !coin.isEmpty else { throw PortfolioShareCodecError.missingCoin }
        guard let amountStr = items["amount"], let amount = Double(amountStr), amount > 0 else {
            throw PortfolioShareCodecError.missingOrInvalidAmount
        }
        return PortfolioShareCode(coinId: coin, amount: amount)
    }
}
```

- [ ] **Step 5: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/PortfolioShareCodecTests
xcodebuild ... test
```
Expected: PortfolioShareCodecTests 10/10; full suite **164 tests** (154 prior + 10 new), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Domain/Entities/PortfolioShareCode.swift CryptoPortfolio/Core/QR/PortfolioShareCodec.swift CryptoPortfolioTests/QR/PortfolioShareCodecTests.swift
git commit -m "feat: add PortfolioShareCode entity and URL-based codec"
```

---

### Task 2: `QRCodeGenerator` (CoreImage)

**Files:**
- Create: `CryptoPortfolio/Core/QR/QRCodeGenerator.swift`
- Test: `CryptoPortfolioTests/QR/QRCodeGeneratorTests.swift`

- [ ] **Step 1: Write the failing test**

Create `CryptoPortfolioTests/QR/QRCodeGeneratorTests.swift`:
```swift
import XCTest
@testable import CryptoPortfolio

final class QRCodeGeneratorTests: XCTestCase {
    func test_generate_returnsImageForNonEmptyString() {
        let image = QRCodeGenerator.generate(text: "cptp://v1?coin=bitcoin&amount=0.5")
        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
        XCTAssertGreaterThan(image?.size.height ?? 0, 0)
    }

    func test_generate_respectsRequestedSize() {
        let image = QRCodeGenerator.generate(text: "hello", size: 200)
        // CoreImage produces an upscaled bitmap; we asked for ~200pt — allow loose match.
        // The size is in pixels (CGImage); we only assert it's clearly upscaled from the
        // tiny native QR size (~ 27 pixels for a short message).
        XCTAssertGreaterThan(image?.size.width ?? 0, 100)
    }
}
```

- [ ] **Step 2: Run; confirm FAIL**

`xcodegen generate && xcodebuild ... test -only-testing:CryptoPortfolioTests/QRCodeGeneratorTests`
Expected: `cannot find 'QRCodeGenerator' in scope`.

- [ ] **Step 3: Create the generator**

`CryptoPortfolio/Core/QR/QRCodeGenerator.swift`:
```swift
import UIKit
import CoreImage

/// Produces a `UIImage` from a string using CoreImage's QR code filter.
/// Returns `nil` for empty strings or generation failure.
enum QRCodeGenerator {
    static func generate(text: String, size: CGFloat = 240) -> UIImage? {
        guard !text.isEmpty,
              let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter?.outputImage else { return nil }
        let scale = max(1, size / ciImage.extent.width)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
```

- [ ] **Step 4: Run targeted + full suite**

```
xcodebuild ... test -only-testing:CryptoPortfolioTests/QRCodeGeneratorTests
xcodebuild ... test
```
Expected: QRCodeGeneratorTests 2/2; full suite **166 tests** (164 prior + 2 new), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CryptoPortfolio/Core/QR/QRCodeGenerator.swift CryptoPortfolioTests/QR/QRCodeGeneratorTests.swift
git commit -m "feat: add CoreImage QRCodeGenerator"
```

---

### Task 3: `QRCodeScannerView` (AVFoundation `UIViewControllerRepresentable`)

OS-coupled; not unit-tested. Build verification only. The simulator has no camera, so `AVCaptureDevice.default(for: .video)` returns nil and the controller renders a black background — acceptable. On device the scanner works.

**Files:**
- Create: `CryptoPortfolio/Core/QR/QRCodeScannerView.swift`

- [ ] **Step 1: Create the scanner**

`CryptoPortfolio/Core/QR/QRCodeScannerView.swift`:
```swift
import SwiftUI
import AVFoundation
import UIKit

/// Wraps an `AVCaptureSession` that delivers QR strings via `onDetect`.
/// Stops the session after the first successful detection so the callback fires once.
struct QRCodeScannerView: UIViewControllerRepresentable {
    let onDetect: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onDetect = onDetect
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var onDetect: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = object.stringValue else { return }
        // Stop on first hit so the callback fires once.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
        onDetect?(string)
    }
}
```

- [ ] **Step 2: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **166 tests** (unchanged — no new tests), 0 failures.

- [ ] **Step 3: Commit**

```bash
git add CryptoPortfolio/Core/QR/QRCodeScannerView.swift
git commit -m "feat: add AVFoundation QRCodeScannerView (camera-coupled)"
```

---

### Task 4: `ShareQRView` (sheet UI) + L10n

UI; build-verify only.

**Files:**
- Create: `CryptoPortfolio/Features/Portfolio/Presentation/ShareQRView.swift`
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`

- [ ] **Step 1: Create the view**

```swift
import SwiftUI

struct ShareQRView: View {
    let code: PortfolioShareCode
    let coinName: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(coinName)
                    .font(.title2.weight(.semibold))

                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 240, height: 240)
                        .overlay { Image(systemName: "qrcode").font(.largeTitle).foregroundStyle(.secondary) }
                }

                Text(encoded)
                    .font(.footnote)
                    .monospaced()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ShareLink(item: encoded) {
                    Label("qr.share.button", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationTitle("qr.share.title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var encoded: String { PortfolioShareCodec.encode(code) }
    private var qrImage: UIImage? { QRCodeGenerator.generate(text: encoded, size: 480) }
}
```

- [ ] **Step 2: Add L10n keys**

Add inside `"strings"` (keep all existing keys intact):
```json
    "qr.share.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Share QR" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "QR paylaş" } }
      }
    },
    "qr.share.button" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Share" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Paylaş" } }
      }
    }
```

- [ ] **Step 3: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **166 tests** (unchanged), 0 failures.

- [ ] **Step 4: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Presentation/ShareQRView.swift CryptoPortfolio/Resources/Localizable.xcstrings
git commit -m "feat: add ShareQRView with QR image + URL + ShareLink"
```

---

### Task 5: Wire `ShareQRView` into PortfolioView via HoldingRow `.contextMenu`

**Files:**
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift`
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add the L10n key**

Add inside `"strings"`:
```json
    "portfolio.shareQR" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Share QR" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "QR paylaş" } }
      }
    }
```

- [ ] **Step 2: Modify `PortfolioView`**

Open `CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift`. Two edits:

A) Add a state for the pending share code. Find:
```swift
    @State private var isShowingAddCoin = false
```
and ADD right after:
```swift
    @State private var sharingCode: PortfolioShareCode?
```

B) Modify the `loadedList(summary:)` function. The current `ForEach(summary.items) { item in NavigationLink { … } label: { HoldingRow(…) } }` becomes (only the inner block of the ForEach changes — keep `.onDelete` and outer Section structure identical):
```swift
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
                    .contextMenu {
                        Button {
                            sharingCode = PortfolioShareCode(coinId: item.holding.coinId, amount: item.holding.amount)
                        } label: {
                            Label("portfolio.shareQR", systemImage: "qrcode")
                        }
                    }
                }
                .onDelete { indices in
                    let ids = indices.map { summary.items[$0].holding.coinId }
                    Task { for id in ids { await viewModel.delete(coinId: id) } }
                }
```

C) Add a `.sheet(item:)` modifier next to the existing AddCoin `.sheet`. Find the existing modifier chain in the `body`:
```swift
                .sheet(isPresented: $isShowingAddCoin) { addCoinSheet }
```
ADD immediately after it:
```swift
                .sheet(item: $sharingCode) { code in
                    ShareQRView(code: code, coinName: code.coinId.capitalized)
                }
```

- [ ] **Step 3: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **166 tests** (unchanged), 0 failures.

- [ ] **Step 4: Commit**

```bash
git add CryptoPortfolio/Features/Portfolio/Presentation/PortfolioView.swift CryptoPortfolio/Resources/Localizable.xcstrings
git commit -m "feat: wire HoldingRow contextMenu to present ShareQRView"
```

---

### Task 6: AddCoin scan flow — `ScanQRSheet` + `AddCoinView` toolbar button + `AmountEntryView` prefill

**Files:**
- Create: `CryptoPortfolio/Features/QRImport/Presentation/ScanQRSheet.swift`
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/AmountEntryView.swift` (add `prefillAmount` init param)
- Modify: `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift` (toolbar Scan button + state + nested sheet for AmountEntryView with prefill)
- Modify: `CryptoPortfolio/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add L10n keys**

Add inside `"strings"`:
```json
    "addCoin.scanQR.button" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Scan QR" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "QR tara" } }
      }
    },
    "addCoin.scanQR.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Scan portfolio QR" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Portföy QR'ı tara" } }
      }
    },
    "addCoin.scanQR.invalid" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Invalid QR code" } },
        "tr" : { "stringUnit" : { "state" : "translated", "value" : "Geçersiz QR kodu" } }
      }
    }
```

- [ ] **Step 2: Create `ScanQRSheet.swift`**

`CryptoPortfolio/Features/QRImport/Presentation/ScanQRSheet.swift`:
```swift
import SwiftUI

/// Presents the camera scanner. On a valid `cptp://` QR detection, calls
/// `onCodeDetected` and dismisses. On an invalid QR, shows a transient error.
struct ScanQRSheet: View {
    let onCodeDetected: (PortfolioShareCode) -> Void
    let onCancel: () -> Void

    @State private var errorMessageKey: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            QRCodeScannerView { raw in
                do {
                    let code = try PortfolioShareCodec.decode(raw)
                    onCodeDetected(code)
                } catch {
                    errorMessageKey = "addCoin.scanQR.invalid"
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                if let key = errorMessageKey {
                    Text(key)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("addCoin.scanQR.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { onCancel() }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Modify `AmountEntryView`**

Open `CryptoPortfolio/Features/Portfolio/Presentation/AmountEntryView.swift`. Find the property declarations near the top:
```swift
    @State private var amountText: String = ""
    @State private var buyPriceText: String = ""
```
Replace them and add an init so the amount can be prefilled:
```swift
    @State private var amountText: String
    @State private var buyPriceText: String = ""

    init(coin: Coin,
         viewModel: AddCoinViewModel,
         prefillAmount: Double? = nil,
         onSave: @escaping (Bool) -> Void) {
        self.coin = coin
        self.viewModel = viewModel
        self.onSave = onSave
        _amountText = State(initialValue: prefillAmount.map { String($0) } ?? "")
    }
```
Do NOT change any other code in this file. The body, save logic, and the `coin` / `viewModel` / `onSave` stored properties stay identical. (`@ObservedObject var viewModel: AddCoinViewModel` and `let coin: Coin` and `let onSave: (Bool) -> Void` must remain as the file currently declares them — the new init just explicitly assigns them rather than relying on the synthesised memberwise init.)

- [ ] **Step 4: Modify `AddCoinView`**

Open `CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift`. Two edits:

A) Add two new `@State` properties. Find the existing declarations near the top of the struct (right after `@StateObject private var viewModel`):
ADD:
```swift
    @State private var isShowingScanner = false
    @State private var scannedCode: PortfolioShareCode?
```

B) Replace the existing `body` with (adds the Scan toolbar item, the scanner sheet, and the follow-up AmountEntry sheet — keep the existing `.searchable`/`.onSubmit`/Cancel toolbar UNCHANGED):
```swift
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("addCoin.title")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("addCoin.search.prompt"))
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone(false) }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isShowingScanner = true } label: {
                            Label("addCoin.scanQR.button", systemImage: "qrcode.viewfinder")
                        }
                    }
                }
                .sheet(isPresented: $isShowingScanner) {
                    ScanQRSheet(
                        onCodeDetected: { code in
                            isShowingScanner = false
                            scannedCode = code
                        },
                        onCancel: { isShowingScanner = false }
                    )
                }
                .sheet(item: $scannedCode) { code in
                    NavigationStack {
                        AmountEntryView(
                            coin: Coin(id: code.coinId, symbol: code.coinId, name: code.coinId.capitalized),
                            viewModel: viewModel,
                            prefillAmount: code.amount
                        ) { saved in
                            scannedCode = nil
                            if saved { onDone(true) }
                        }
                    }
                }
        }
    }
```

NOTE: do not touch the existing `content` computed property, the inner `NavigationLink { AmountEntryView(coin: coin, viewModel: viewModel) { onDone($0) } } label: { coinRow(coin) }` (which still calls `AmountEntryView` WITHOUT `prefillAmount` — that's fine because `prefillAmount` defaults to nil), or the `coinRow(_:)` helper.

- [ ] **Step 5: Build + full suite**

```
xcodegen generate
xcodebuild ... build
xcodebuild ... test
```
Expected: `** BUILD SUCCEEDED **`; full suite **166 tests** (unchanged), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add CryptoPortfolio/Features/QRImport CryptoPortfolio/Features/Portfolio/Presentation/AmountEntryView.swift CryptoPortfolio/Features/Portfolio/Presentation/AddCoinView.swift CryptoPortfolio/Resources/Localizable.xcstrings
git commit -m "feat: add QR scan toolbar button to AddCoin; route to AmountEntry with prefilled amount"
```

---

### Task 7: Simulator launch + screenshot

Camera-side scanning is not exercisable on the simulator (no camera). The Share QR side is fully exercisable interactively (long-press a holding row → context menu → Share QR). Since the seeded simulator has an empty portfolio (no holdings), the launch screenshot below captures the Portfolio empty state with all three tabs — sufficient evidence the app launches cleanly with the new code.

**Files:**
- Create: `docs/screenshots/phase6-launch.png` (best-effort)

- [ ] **Step 1: Launch + capture**

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
xcrun simctl io booted screenshot docs/screenshots/phase6-launch.png
file docs/screenshots/phase6-launch.png
```

If `simctl io booted screenshot` fails completely, skip the screenshot and continue.

- [ ] **Step 2: Commit**

```bash
git add docs/screenshots/
git status
git commit -m "docs: add phase6 launch screenshot"
```
Verify `git status` between `add` and `commit` that `build/`, `.xcodeproj/`, and `Config/Secrets.xcconfig` are NOT staged.

---

## Self-Review

**1. Spec coverage (§11 QR format):**
- URL format `cptp://v1?coin=<coinId>&amount=<decimal>` → Task 1 ✅
- CoreImage QR generation → Task 2 ✅
- AVFoundation QR scanning → Task 3 ✅
- Portfolio item share QR (HoldingRow → context menu → ShareQRView) → Tasks 4, 5 ✅
- AddCoin scan QR → AmountEntryView with prefilled amount → Task 6 ✅
- L10n (tr/en) → Tasks 4, 5, 6 ✅

Deliberately deferred (NOT in Phase 6):
- Network resolution of scanned coin (name/image) — the materialised `Coin` uses `coinId.capitalized` for the name and no image. A future enhancement could call `SearchCoinsUseCase` after scan.
- CoinDetail "Share QR" — Phase 7 polish.
- A custom scanning frame overlay (Apple-style guide rectangle) — visual polish for Phase 7.

**2. Placeholder scan:** No "TBD"/"TODO"/"add validation"-style placeholders. Every code step has complete code; every command has an expected output and a test count progression. The Task 7 screenshot step is genuinely best-effort and clearly marked.

**3. Type consistency:**
- `PortfolioShareCode(coinId:amount:)` + `.id` (concat) used identically in Tasks 1, 5, 6. Equatable + Identifiable conformance correct.
- `PortfolioShareCodec.encode(_:)` / `.decode(_:)` and `PortfolioShareCodecError` cases match across Tasks 1, 4 (ShareQRView), 6 (ScanQRSheet).
- `QRCodeGenerator.generate(text:size:) -> UIImage?` consistent in Tasks 2, 4.
- `QRCodeScannerView(onDetect:)` closure type matches ScanQRSheet's caller. The scanner is a UIViewControllerRepresentable; `QRScannerViewController` is the underlying UIKit class.
- `ShareQRView(code:coinName:)` consistent in Tasks 4, 5.
- `ScanQRSheet(onCodeDetected:onCancel:)` consistent in Tasks 6.
- `AmountEntryView(coin:viewModel:prefillAmount:onSave:)` — `prefillAmount` defaults to nil so the existing call site in `AddCoinView.content` (which omits the parameter) keeps working unchanged.
- `Coin(id:symbol:name:imageURL:currentPrice:priceChangePercentage24h:marketCap:high24h:low24h:)` init defaults nil for new optional fields — calling with just `id:symbol:name:` (as ScanQRSheet does via Task 6 Step 4) compiles. ✅
- L10n keys (`qr.share.title`, `qr.share.button`, `portfolio.shareQR`, `addCoin.scanQR.button`, `addCoin.scanQR.title`, `addCoin.scanQR.invalid`) used in Tasks 4, 5, 6 match the keys added in the same tasks. ✅
- Test count progression: 154 (start) → 164 (T1) → 166 (T2) → 166 (T3) → 166 (T4) → 166 (T5) → 166 (T6) → 166 (T7). ✅

No issues found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-01-crypto-portfolio-ios-phase6-qr.md`.
