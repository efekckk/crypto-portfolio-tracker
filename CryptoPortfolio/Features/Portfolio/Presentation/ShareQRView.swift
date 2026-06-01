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
