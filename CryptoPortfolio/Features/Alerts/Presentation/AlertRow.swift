import SwiftUI

struct AlertRow: View {
    let alert: PriceAlert
    let currency: Currency
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            directionIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.coinId.capitalized)
                    .font(.body.weight(.semibold))
                HStack(spacing: 4) {
                    Text(directionLabel)
                    Text(CurrencyFormatter.format(alert.targetPrice, currency: currency))
                        .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if alert.firedAt != nil {
                    Text("alerts.fired")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.positive)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { alert.isActive }, set: { onToggle($0) }))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private var directionIcon: some View {
        Image(systemName: alert.direction == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            .foregroundStyle(alert.direction == .above ? Theme.positive : Theme.negative)
            .font(.title2)
    }

    private var directionLabel: LocalizedStringKey {
        alert.direction == .above ? "alerts.direction.above" : "alerts.direction.below"
    }
}
