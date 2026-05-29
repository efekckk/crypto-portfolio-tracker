import SwiftUI

struct HoldingRow: View {
    let valuation: HoldingValuation
    let currency: Currency

    var body: some View {
        HStack(spacing: 12) {
            coinImage
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body.weight(.semibold))
                Text("\(formattedAmount) \(symbol)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(valuation.currentValue, currency: currency))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                PriceChangeLabel(percent: valuation.percentPnL)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        valuation.coin?.name ?? valuation.holding.coinId.capitalized
    }

    private var symbol: String {
        (valuation.coin?.symbol ?? "").uppercased()
    }

    private var formattedAmount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        return f.string(from: NSNumber(value: valuation.holding.amount)) ?? "\(valuation.holding.amount)"
    }

    @ViewBuilder private var coinImage: some View {
        if let url = valuation.coin?.imageURL {
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
