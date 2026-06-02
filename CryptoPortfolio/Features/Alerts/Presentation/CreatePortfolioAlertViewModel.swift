import Foundation

@MainActor
final class CreatePortfolioAlertViewModel: ObservableObject {
    enum Metric: String, CaseIterable, Identifiable {
        case value, pnlPercent
        var id: String { rawValue }
    }

    let metric: Metric
    @Published var direction: AlertCondition.Direction = .above
    @Published var thresholdText: String = ""
    @Published var recurrence: RecurrencePickerState = RecurrencePickerState()
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let createAlert: CreateAlertUseCase

    init(metric: Metric, createAlert: CreateAlertUseCase) {
        self.metric = metric
        self.createAlert = createAlert
    }

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

        let condition: AlertCondition
        switch metric {
        case .value:      condition = .portfolioValue(direction: direction, threshold: value)
        case .pnlPercent: condition = .portfolioPnLPercent(direction: direction, threshold: value)
        }

        do {
            try createAlert(condition: condition, recurrence: recurrence.recurrence)
            return true
        } catch AlertError.invalidPrice {
            saveError = String(localized: "createAlert.error.priceNotPositive",
                               defaultValue: "Target price must be greater than zero.")
            return false
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
