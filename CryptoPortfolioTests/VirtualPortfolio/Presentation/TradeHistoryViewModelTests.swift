import XCTest
@testable import CryptoPortfolio

@MainActor
final class TradeHistoryViewModelTests: XCTestCase {

    final class MockAPI: VirtualPortfolioAPI {
        /// FIFO queue of results, one per call. Test sets these up in order.
        var pages: [Result<VirtualTradeHistoryPage, Error>] = []
        private(set) var calls: [(beforeID: Int64?, limit: Int)] = []

        func listPortfolios() async throws -> [VirtualPortfolioSummary] { fatalError("not used") }
        func getPortfolio(id: UUID) async throws -> VirtualPortfolio { fatalError("not used") }
        func createPortfolio(name: String, startingBalance: Double) async throws -> VirtualPortfolioSummary { fatalError("not used") }
        func deletePortfolio(id: UUID) async throws { fatalError("not used") }
        func quote(portfolioID: UUID, coinID: String) async throws -> VirtualQuote { fatalError("not used") }
        func executeTrade(portfolioID: UUID, side: VirtualTrade.Side, coinID: String, amount: Double) async throws -> VirtualPortfolio { fatalError("not used") }
        func tradeHistory(portfolioID: UUID, beforeID: Int64?, limit: Int) async throws -> VirtualTradeHistoryPage {
            calls.append((beforeID, limit))
            guard !pages.isEmpty else { throw VirtualAPIError.unknown(999, "no more mock pages") }
            return try pages.removeFirst().get()
        }
    }

    private func makeTrade(id: Int64, side: VirtualTrade.Side = .buy) -> VirtualTrade {
        VirtualTrade(
            id: id,
            side: side,
            coinId: "bitcoin",
            amount: 0.05,
            price: 80_000,
            executedAt: Date()
        )
    }

    private func makeVM(_ mock: MockAPI, pageSize: Int = 50) -> TradeHistoryViewModel {
        TradeHistoryViewModel(portfolioID: UUID(), api: mock, pageSize: pageSize)
    }

    // MARK: - First page

    func test_load_emptyFirstPage_setsEmptyState() async {
        let mock = MockAPI()
        mock.pages = [.success(VirtualTradeHistoryPage(trades: [], nextCursor: nil))]
        let vm = makeVM(mock)
        await vm.load()
        if case .empty = vm.state {} else { XCTFail("expected .empty, got \(vm.state)") }
        XCTAssertFalse(vm.hasMore)
    }

    func test_load_singlePage_setsLoadedAndNoMore() async {
        let mock = MockAPI()
        let trades = [makeTrade(id: 3), makeTrade(id: 2), makeTrade(id: 1)]
        mock.pages = [.success(VirtualTradeHistoryPage(trades: trades, nextCursor: nil))]
        let vm = makeVM(mock)
        await vm.load()
        guard case .loaded(let rows) = vm.state else {
            XCTFail("expected .loaded")
            return
        }
        XCTAssertEqual(rows.count, 3)
        XCTAssertFalse(vm.hasMore)
    }

    func test_load_pagedFirstPage_setsLoadedAndHasMore() async {
        let mock = MockAPI()
        let trades = (1...50).reversed().map { Int64($0) }.map { makeTrade(id: $0) }
        mock.pages = [.success(VirtualTradeHistoryPage(trades: trades, nextCursor: 1))]
        let vm = makeVM(mock)
        await vm.load()
        guard case .loaded(let rows) = vm.state else {
            XCTFail("expected .loaded")
            return
        }
        XCTAssertEqual(rows.count, 50)
        XCTAssertTrue(vm.hasMore)
    }

    func test_load_error_setsErrorState() async {
        let mock = MockAPI()
        mock.pages = [.failure(VirtualAPIError.upstream("down"))]
        let vm = makeVM(mock)
        await vm.load()
        if case .error(let msg) = vm.state {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("expected .error")
        }
        XCTAssertFalse(vm.hasMore)
    }

    // MARK: - Pagination

    func test_loadMore_appendsAndAdvancesCursor() async {
        let mock = MockAPI()
        let page1 = (51...100).reversed().map { Int64($0) }.map { makeTrade(id: $0) }
        let page2 = (1...50).reversed().map { Int64($0) }.map { makeTrade(id: $0) }
        mock.pages = [
            .success(VirtualTradeHistoryPage(trades: page1, nextCursor: 51)),
            .success(VirtualTradeHistoryPage(trades: page2, nextCursor: nil))
        ]
        let vm = makeVM(mock)
        await vm.load()
        await vm.loadMore()

        guard case .loaded(let rows) = vm.state else {
            XCTFail("expected .loaded")
            return
        }
        XCTAssertEqual(rows.count, 100)
        XCTAssertEqual(mock.calls.count, 2)
        XCTAssertNil(mock.calls[0].beforeID)
        XCTAssertEqual(mock.calls[1].beforeID, 51)
        XCTAssertFalse(vm.hasMore)
    }

    func test_loadMore_noCursor_isNoOp() async {
        let mock = MockAPI()
        let trades = [makeTrade(id: 1)]
        mock.pages = [.success(VirtualTradeHistoryPage(trades: trades, nextCursor: nil))]
        let vm = makeVM(mock)
        await vm.load()
        await vm.loadMore() // no-op: hasMore is false

        XCTAssertEqual(mock.calls.count, 1)
    }

    func test_loadMore_beforeLoad_isNoOp() async {
        let mock = MockAPI()
        let vm = makeVM(mock)
        await vm.loadMore() // state is .loading, no cursor
        XCTAssertEqual(mock.calls.count, 0)
    }

    func test_loadMore_error_stopsPaginationButKeepsRows() async {
        let mock = MockAPI()
        let page1 = (1...50).reversed().map { Int64($0) }.map { makeTrade(id: $0) }
        mock.pages = [
            .success(VirtualTradeHistoryPage(trades: page1, nextCursor: 1)),
            .failure(VirtualAPIError.upstream("down"))
        ]
        let vm = makeVM(mock)
        await vm.load()
        await vm.loadMore()

        guard case .loaded(let rows) = vm.state else {
            XCTFail("expected rows to stay loaded")
            return
        }
        XCTAssertEqual(rows.count, 50)
        XCTAssertFalse(vm.hasMore)
    }

    // MARK: - Page size

    func test_load_usesConfiguredPageSize() async {
        let mock = MockAPI()
        mock.pages = [.success(VirtualTradeHistoryPage(trades: [], nextCursor: nil))]
        let vm = makeVM(mock, pageSize: 25)
        await vm.load()
        XCTAssertEqual(mock.calls[0].limit, 25)
    }
}
