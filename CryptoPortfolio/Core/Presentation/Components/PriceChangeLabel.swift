import SwiftUI

/// Signed percent change colored by `Theme`. Caller passes the raw percent value
/// (e.g. `2.5` for +2.50 %).
struct PriceChangeLabel: View {
    let percent: Double

    var body: some View {
        Text(CurrencyFormatter.formatPercent(percent))
            .foregroundStyle(Theme.color(forChange: percent))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
    }
}
