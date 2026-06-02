import SwiftUI

struct AlertRow: View {
    let alert: PriceAlert
    let currency: Currency
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTextKey)
                    .font(.body.weight(.semibold))
                if let secondary = secondaryTextKey {
                    Text(secondary).font(.subheadline).foregroundStyle(.secondary)
                }
                if let plain = primaryTextPlain {
                    Text(plain).font(.body.weight(.semibold))
                }
                Text(recurrenceLabelKey)
                    .font(.caption)
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

    // MARK: - Per-variant derivations

    private var iconView: some View {
        let (systemName, color): (String, Color) = {
            switch alert.condition {
            case .priceCrossing(_, let dir, _):
                return (dir == .above ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        dir == .above ? Theme.positive : Theme.negative)
            case .percentChange(_, let dir, _, _):
                return (dir == .above ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                        dir == .above ? Theme.positive : Theme.negative)
            case .portfolioValue:
                return ("briefcase.fill", Theme.accent)
            case .portfolioPnLPercent:
                return ("chart.pie.fill", Theme.accent)
            }
        }()
        return Image(systemName: systemName)
            .foregroundStyle(color)
            .font(.title2)
    }

    /// We split presentation into:
    ///   - `primaryTextKey`: a LocalizedStringKey for portfolio variants
    ///   - `primaryTextPlain`: a plain composed string for coin variants
    ///     (because the coin name + formatted price aren't a single key).
    /// Exactly one of the two is non-nil at a time.
    private var primaryTextKey: LocalizedStringKey {
        switch alert.condition {
        case .portfolioValue:        return "alerts.row.portfolioValue"
        case .portfolioPnLPercent:   return "alerts.row.portfolioPnLPercent"
        case .priceCrossing, .percentChange:
            return "" // overridden by primaryTextPlain
        }
    }

    private var primaryTextPlain: String? {
        switch alert.condition {
        case .priceCrossing(let coinId, _, let target):
            return "\(coinId.capitalized)  \(CurrencyFormatter.format(target, currency: currency))"
        case .percentChange(let coinId, _, let window, let threshold):
            return "\(coinId.capitalized)  \(formatPercent(threshold)) (\(windowSuffix(window)))"
        case .portfolioValue, .portfolioPnLPercent:
            return nil
        }
    }

    private var secondaryTextKey: LocalizedStringKey? {
        switch alert.condition {
        case .priceCrossing(_, let dir, _), .percentChange(_, let dir, _, _),
             .portfolioValue(let dir, _), .portfolioPnLPercent(let dir, _):
            return dir == .above ? "alerts.direction.above" : "alerts.direction.below"
        }
    }

    private var recurrenceLabelKey: LocalizedStringKey {
        switch alert.recurrence {
        case .oneShot:    return "alerts.recurrence.oneShot"
        case .cooldown:   return "alerts.recurrence.cooldown"
        case .onCrossing: return "alerts.recurrence.onCrossing"
        }
    }

    private func windowSuffix(_ window: AlertCondition.PercentWindow) -> String {
        switch window {
        case .h24: return String(localized: "alerts.window.h24", defaultValue: "24h")
        case .d7:  return String(localized: "alerts.window.d7",  defaultValue: "7d")
        case .d30: return String(localized: "alerts.window.d30", defaultValue: "30d")
        }
    }

    /// Locale-aware percent formatting so "5" renders as "5%" rather than
    /// "5.0%". Mirrors the formatter used in AlertNotificationFormatter.
    private func formatPercent(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        let n = nf.string(from: NSNumber(value: value)) ?? String(value)
        return "\(n)%"
    }
}
