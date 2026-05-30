import SwiftUI

struct CoinDetailHeaderView: View {
    let coin: Coin
    let currency: Currency

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                coinImage
                VStack(alignment: .leading) {
                    Text(coin.name).font(.title2.weight(.semibold))
                    Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(CurrencyFormatter.format(coin.currentPrice, currency: currency))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                Spacer()
                PriceChangeLabel(percent: coin.priceChangePercentage24h)
            }
        }
    }

    @ViewBuilder private var coinImage: some View {
        if let url = coin.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                default: Circle().fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            Circle().fill(.secondary.opacity(0.2)).frame(width: 44, height: 44)
        }
    }
}
