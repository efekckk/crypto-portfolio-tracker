import Foundation

/// Backs the type-chooser/search step of the Create-Alert flow. Each form
/// downstream owns its own VM (CreatePriceAlertViewModel, CreatePercentAlertViewModel,
/// CreatePortfolioAlertViewModel).
@MainActor
final class CreateAlertViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty

    private let searchCoins: SearchCoinsUseCase

    init(searchCoins: SearchCoinsUseCase) {
        self.searchCoins = searchCoins
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
}
