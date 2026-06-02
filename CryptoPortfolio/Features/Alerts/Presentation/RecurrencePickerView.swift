import SwiftUI

/// Light value-type state model shared by every Create*AlertViewModel.
/// Forms own one of these and read `recurrence` when saving.
struct RecurrencePickerState: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case oneShot, cooldown, onCrossing
        var id: String { rawValue }
    }
    var kind: Kind = .oneShot
    /// Only consulted when `kind == .cooldown`. Default 1 hour.
    var cooldownSeconds: TimeInterval = 3600

    /// The `Recurrence` value to persist.
    var recurrence: Recurrence {
        switch kind {
        case .oneShot:    return .oneShot
        case .cooldown:   return .cooldown(seconds: cooldownSeconds)
        case .onCrossing: return .onCrossing
        }
    }
}

/// Inline Form section. Place inside a parent `Form { ... }`.
struct RecurrencePickerView: View {
    @Binding var state: RecurrencePickerState

    private static let cooldownPresets: [(label: LocalizedStringKey, seconds: TimeInterval)] = [
        ("alerts.cooldown.1h", 3600),
        ("alerts.cooldown.6h", 21600),
        ("alerts.cooldown.24h", 86400)
    ]

    var body: some View {
        Section {
            Picker("alerts.form.recurrence", selection: $state.kind) {
                Text("alerts.recurrence.oneShot").tag(RecurrencePickerState.Kind.oneShot)
                Text("alerts.recurrence.cooldown").tag(RecurrencePickerState.Kind.cooldown)
                Text("alerts.recurrence.onCrossing").tag(RecurrencePickerState.Kind.onCrossing)
            }
            if state.kind == .cooldown {
                Picker("alerts.cooldown.interval", selection: $state.cooldownSeconds) {
                    ForEach(Self.cooldownPresets, id: \.seconds) { preset in
                        Text(preset.label).tag(preset.seconds)
                    }
                }
            }
        }
    }
}
