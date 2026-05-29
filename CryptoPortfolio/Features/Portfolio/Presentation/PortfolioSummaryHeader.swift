import SwiftUI

struct PortfolioSummaryHeader: View {
    let summary: PortfolioSummary
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("portfolio.totalValue")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(CurrencyFormatter.format(summary.totalValue, currency: currency))
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()

            HStack(spacing: 8) {
                Text(CurrencyFormatter.format(summary.absolutePnL, currency: currency))
                    .foregroundStyle(Theme.color(forChange: summary.absolutePnL))
                    .monospacedDigit()
                PriceChangeLabel(percent: summary.percentPnL)
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
