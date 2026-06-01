import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var state: ViewState<PortfolioSummary> = .loading

    private let getSummary: GetPortfolioSummaryUseCase
    private let removeHolding: RemoveHoldingUseCase
    let currency: Currency

    init(getSummary: GetPortfolioSummaryUseCase,
         removeHolding: RemoveHoldingUseCase,
         currency: Currency = .default) {
        self.getSummary = getSummary
        self.removeHolding = removeHolding
        self.currency = currency
    }

    func load() async {
        state = .loading
        do {
            let summary = try await getSummary(currency: currency)
            state = summary.items.isEmpty ? .empty : .loaded(summary)
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func refresh() async { await load() }

    func delete(coinId: String) async {
        do {
            try removeHolding(coinId: coinId)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }
}
