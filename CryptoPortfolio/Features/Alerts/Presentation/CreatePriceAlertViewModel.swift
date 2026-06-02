import Foundation

@MainActor
final class CreatePriceAlertViewModel: ObservableObject {
    let coin: Coin
    @Published var direction: AlertCondition.Direction = .above
    @Published var targetPriceText: String = ""
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

        let normalized = targetPriceText.replacingOccurrences(of: ",", with: ".")
        guard let price = Double(normalized) else {
            saveError = String(localized: "createAlert.error.priceNotNumber",
                               defaultValue: "Target price is not a number.")
            return false
        }
        do {
            try createAlert(
                condition: .priceCrossing(coinId: coin.id, direction: direction, targetPrice: price),
                recurrence: recurrence.recurrence
            )
            return true
        } catch AlertError.invalidPrice {
            saveError = String(localized: "createAlert.error.priceNotPositive",
                               defaultValue: "Target price must be greater than zero.")
            return false
        } catch {
            saveError = String(localized: "createAlert.error.saveFailed",
                               defaultValue: "Could not save alert.")
            return false
        }
    }

    func clearSaveError() { saveError = nil }
}
