import Foundation

@MainActor
final class CreateAlertViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let searchCoins: SearchCoinsUseCase
    private let createAlert: CreateAlertUseCase

    init(searchCoins: SearchCoinsUseCase, createAlert: CreateAlertUseCase) {
        self.searchCoins = searchCoins
        self.createAlert = createAlert
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { results = .empty; return }
        results = .loading
        do {
            let coins = try await searchCoins(trimmed)
            results = coins.isEmpty ? .empty : .loaded(coins)
        } catch {
            results = .error(error.userFacingMessage)
        }
    }

    /// Returns true if the alert was saved successfully.
    func save(coin: Coin, direction: PriceAlert.Direction, targetPriceText: String) async -> Bool {
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
            try createAlert(coinId: coin.id, targetPrice: price, direction: direction)
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
