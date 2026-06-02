import Foundation

@MainActor
final class CreatePercentAlertViewModel: ObservableObject {
    let coin: Coin
    @Published var window: AlertCondition.PercentWindow = .h24
    @Published var direction: AlertCondition.Direction = .above
    @Published var thresholdText: String = ""
    @Published var recurrence: RecurrencePickerState = RecurrencePickerState()
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let createAlert: CreateAlertUseCase

    init(coin: Coin, createAlert: CreateAlertUseCase) {
        self.coin = coin
        self.createAlert = createAlert
    }

    /// Returns true iff the alert was saved successfully.
    func save() async -> Bool {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let normalized = thresholdText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else {
            saveError = String(localized: "createAlert.error.thresholdNotNumber",
                               defaultValue: "Threshold is not a number.")
            return false
        }
        do {
            try createAlert(
                condition: .percentChange(coinId: coin.id, direction: direction,
                                          window: window, threshold: value),
                recurrence: recurrence.recurrence
            )
            return true
        } catch AlertError.invalidThreshold {
            saveError = String(localized: "createAlert.error.thresholdZero",
                               defaultValue: "Threshold cannot be zero.")
            return false
        } catch {
            saveError = String(localized: "createAlert.error.saveFailed",
                               defaultValue: "Could not save alert.")
            return false
        }
    }

    func clearSaveError() { saveError = nil }
}
