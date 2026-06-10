import Foundation

/// Backs the detail screen for a single virtual portfolio.
///
/// State machine:
/// - `.loading` on first load and pull-to-refresh
/// - `.loaded(...)` with the full detail (cash, holdings, P/L)
/// - `.error(...)` when the load fails and there is no prior snapshot
///
/// Non-fatal delete failures land in `lastError`. A successful delete
/// flips `wasDeleted` so the view can pop. After a trade, the view passes
/// the post-trade snapshot via `applyPostTradeUpdate` and we drop straight
/// into `.loaded` without a network round trip.
@MainActor
final class VirtualPortfolioDetailViewModel: ObservableObject {
    @Published private(set) var state: ViewState<VirtualPortfolio> = .loading
    @Published private(set) var lastError: String?
    @Published private(set) var wasDeleted: Bool = false

    let portfolioID: UUID
    private let api: VirtualPortfolioAPI

    init(portfolioID: UUID, api: VirtualPortfolioAPI) {
        self.portfolioID = portfolioID
        self.api = api
    }

    /// Loads (or reloads) the detail. Clears `lastError`.
    func load() async {
        state = .loading
        lastError = nil
        do {
            let portfolio = try await api.getPortfolio(id: portfolioID)
            state = .loaded(portfolio)
        } catch let error as VirtualAPIError {
            state = .error(error.userFacingMessage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Issues the delete, then flips `wasDeleted` on success. On failure the
    /// detail stays mounted and `lastError` carries the message.
    func delete() async {
        lastError = nil
        do {
            try await api.deletePortfolio(id: portfolioID)
            wasDeleted = true
        } catch let error as VirtualAPIError {
            lastError = error.userFacingMessage
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The trade endpoint returns the post-trade portfolio snapshot
    /// alongside the new trade row. Letting the trade sheet hand that
    /// snapshot straight to the detail VM avoids an extra GET.
    func applyPostTradeUpdate(_ portfolio: VirtualPortfolio) {
        state = .loaded(portfolio)
        lastError = nil
    }
}
