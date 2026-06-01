import SwiftUI

struct WatchlistRow: View {
    let coin: Coin
    let currency: Currency

    var body: some View {
        HStack(spacing: 12) {
            coinImage
            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(coin.currentPrice, currency: currency))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                PriceChangeLabel(percent: coin.priceChangePercentage24h)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var coinImage: some View {
        if let url = coin.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                default: Circle().fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            Circle().fill(.secondary.opacity(0.2)).frame(width: 36, height: 36)
        }
    }
}
