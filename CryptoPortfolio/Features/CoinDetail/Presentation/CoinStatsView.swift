import SwiftUI

struct CoinStatsView: View {
    let coin: Coin
    let currency: Currency

    var body: some View {
        VStack(spacing: 12) {
            statRow(labelKey: "coinDetail.stats.marketCap", value: coin.marketCap)
            statRow(labelKey: "coinDetail.stats.high24h", value: coin.high24h)
            statRow(labelKey: "coinDetail.stats.low24h", value: coin.low24h)
        }
    }

    @ViewBuilder
    private func statRow(labelKey: LocalizedStringKey, value: Double?) -> some View {
        HStack {
            Text(labelKey).foregroundStyle(.secondary)
            Spacer()
            Text(value.map { CurrencyFormatter.format($0, currency: currency) } ?? "—")
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}
