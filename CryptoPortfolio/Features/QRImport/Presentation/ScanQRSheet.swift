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
