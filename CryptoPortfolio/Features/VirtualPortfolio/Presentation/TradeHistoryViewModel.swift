import Foundation

/// Backs the trade history list for a single virtual portfolio.
///
/// First page loads via `load()`. As the user scrolls past the
/// last visible row, the view calls `loadMore()` which follows
/// `nextCursor` until the backend says there's nothing left. A
/// concurrent guard prevents duplicate fetches if scroll events
/// fire in quick succession.
@MainActor
final class TradeHistoryViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[VirtualTrade]> = .loading
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var hasMore: Bool = true

    let portfolioID: UUID

    private let api: VirtualPortfolioAPI
    private let pageSize: Int
    private var nextCursor: Int64?
    private var inFlight: Bool = false

    init(portfolioID: UUID, api: VirtualPortfolioAPI, pageSize: Int = 50) {
        self.portfolioID = portfolioID
        self.api = api
        self.pageSize = pageSize
    }

    /// Loads (or reloads) the first page from scratch.
    func load() async {
        guard !inFlight else { return }
        inFlight = true
        defer { inFlight = false }

        state = .loading
        nextCursor = nil
        hasMore = true

        do {
            let page = try await api.tradeHistory(portfolioID: portfolioID,
                                                  beforeID: nil,
                                                  limit: pageSize)
            if page.trades.isEmpty {
                state = .empty
                hasMore = false
            } else {
                state = .loaded(page.trades)
                nextCursor = page.nextCursor
                hasMore = page.nextCursor != nil
            }
        } catch let error as VirtualAPIError {
            state = .error(error.userFacingMessage)
            hasMore = false
        } catch {
            state = .error(error.localizedDescription)
            hasMore = false
        }
    }

    /// Fetches the next page and appends. No-op if already loading,
    /// no cursor left, or the list isn't in `.loaded` state.
    func loadMore() async {
        guard !inFlight, hasMore, let cursor = nextCursor else { return }
        guard case .loaded(let current) = state else { return }
        inFlight = true
        isLoadingMore = true
        defer {
            inFlight = false
            isLoadingMore = false
        }

        do {
            let page = try await api.tradeHistory(portfolioID: portfolioID,
                                                  beforeID: cursor,
                                                  limit: pageSize)
            state = .loaded(current + page.trades)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
        } catch let error as VirtualAPIError {
            // Keep the rows we already have; surface the error via a
            // transient state field. For now we just stop pagination
            // — the next user action (pull-to-refresh) will retry.
            hasMore = false
            _ = error // intentionally swallowed; future: expose a banner
        } catch {
            hasMore = false
        }
    }
}
