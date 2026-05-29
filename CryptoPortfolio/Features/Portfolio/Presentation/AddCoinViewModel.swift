import Foundation

@MainActor
final class AddCoinViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty
    @Published private(set) var saveError: String?
    @Published private(set) var isSaving: Bool = false

    private let searchCoins: SearchCoinsUseCase
    private let addHolding: AddHoldingUseCase

    init(searchCoins: SearchCoinsUseCase, addHolding: AddHoldingUseCase) {
        self.searchCoins = searchCoins
        self.addHolding = addHolding
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = .empty
            return
        }
        results = .loading
        do {
            let coins = try await searchCoins(trimmed)
            results = coins.isEmpty ? .empty : .loaded(coins)
        } catch {
            results = .error(PortfolioViewModel.userFacingMessage(for: error))
        }
    }

    func add(coinId: String, amount: Double, buyPrice: Double) async -> Bool {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            try addHolding(coinId: coinId, amount: amount, buyPrice: buyPrice)
            return true
        } catch PortfolioError.invalidAmount {
            saveError = "Amount must be greater than zero."
            return false
        } catch {
            saveError = "Could not save holding."
            return false
        }
    }

    /// Clears any previously set save error (e.g. when the user navigates to a fresh form).
    func clearSaveError() {
        saveError = nil
    }
}
