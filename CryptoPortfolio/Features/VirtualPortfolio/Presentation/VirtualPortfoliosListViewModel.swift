import Foundation

/// Backs the tab's list of virtual portfolios.
///
/// State machine:
/// - `.loading` on first load, on pull-to-refresh, and on delete-reload
/// - `.empty` when the list is empty
/// - `.loaded(...)` with the portfolio summaries
/// - `.error(...)` with a localized message
///
/// `lastError` is also exposed so views can surface an inline banner after
/// a transient failure without dropping the previously loaded data.
@MainActor
final class VirtualPortfoliosListViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[VirtualPortfolioSummary]> = .loading
    /// Non-fatal errors (e.g. delete failed but the list is still valid).
    @Published private(set) var lastError: String?

    private let api: VirtualPortfolioAPI

    init(api: VirtualPortfolioAPI) {
        self.api = api
    }

    /// Loads the list. Used for first appear, pull-to-refresh, and after
    /// any mutation. Clears `lastError`.
    func load() async {
        state = .loading
        lastError = nil
        do {
            let portfolios = try await api.listPortfolios()
            state = portfolios.isEmpty ? .empty : .loaded(portfolios)
        } catch let error as VirtualAPIError {
            state = .error(error.userFacingMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Deletes a portfolio, then reloads. On failure the list stays as is
    /// and `lastError` carries the message for the caller to surface inline.
    func delete(id: UUID) async {
        lastError = nil
        do {
            try await api.deletePortfolio(id: id)
            await load()
        } catch let error as VirtualAPIError {
            lastError = error.userFacingMessage
        } catch {
            lastError = error.localizedDescription
        }
    }
}
