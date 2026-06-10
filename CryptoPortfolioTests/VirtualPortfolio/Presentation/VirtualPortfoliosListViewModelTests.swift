import XCTest
@testable import CryptoPortfolio

@MainActor
final class VirtualPortfoliosListViewModelTests: XCTestCase {

    // MARK: - Mock

    final class MockVirtualPortfolioAPI: VirtualPortfolioAPI {
        var listResult: Result<[VirtualPortfolioSummary], Error> = .success([])
        var deleteResult: Result<Void, Error> = .success(())
        private(set) var deletedIDs: [UUID] = []

        func listPortfolios() async throws -> [VirtualPortfolioSummary] {
            try listResult.get()
        }
        func getPortfolio(id: UUID) async throws -> VirtualPortfolio { fatalError("not used") }
        func createPortfolio(name: String, startingBalance: Double) async throws -> VirtualPortfolioSummary { fatalError("not used") }
        func deletePortfolio(id: UUID) async throws {
            deletedIDs.append(id)
            try deleteResult.get()
        }
        func quote(portfolioID: UUID, coinID: String) async throws -> VirtualQuote { fatalError("not used") }
        func executeTrade(portfolioID: UUID, side: VirtualTrade.Side, coinID: String, amount: Double) async throws -> VirtualPortfolio { fatalError("not used") }
        func tradeHistory(portfolioID: UUID, beforeID: Int64?, limit: Int) async throws -> VirtualTradeHistoryPage { fatalError("not used") }
    }

    // MARK: - Helpers

    private func makeSummary(name: String = "Test") -> VirtualPortfolioSummary {
        VirtualPortfolioSummary(
            id: UUID(), name: name, startingBalance: 10000,
            cashBalance: 10000, totalValue: 10000,
            totalPnL: 0, totalPnLPercent: 0,
            tradeCount: 0, createdAt: Date(), updatedAt: Date()
        )
    }

    // MARK: - Tests

    func test_load_emptyResponse_setsEmptyState() async {
        let mock = MockVirtualPortfolioAPI()
        mock.listResult = .success([])
        let vm = VirtualPortfoliosListViewModel(api: mock)

        await vm.load()

        guard case .empty = vm.state else {
            XCTFail("expected .empty, got \(vm.state)")
            return
        }
    }

    func test_load_nonEmptyResponse_setsLoaded() async {
        let mock = MockVirtualPortfolioAPI()
        mock.listResult = .success([makeSummary(name: "A"), makeSummary(name: "B")])
        let vm = VirtualPortfoliosListViewModel(api: mock)

        await vm.load()

        guard case .loaded(let items) = vm.state else {
            XCTFail("expected .loaded, got \(vm.state)")
            return
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.name), ["A", "B"])
    }

    func test_load_apiError_setsErrorWithLocalizedMessage() async {
        let mock = MockVirtualPortfolioAPI()
        mock.listResult = .failure(VirtualAPIError.upstream("down"))
        let vm = VirtualPortfoliosListViewModel(api: mock)

        await vm.load()

        guard case .error(let message) = vm.state else {
            XCTFail("expected .error, got \(vm.state)")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    func test_delete_happyPath_reloadsList() async {
        let mock = MockVirtualPortfolioAPI()
        let pid = UUID()
        let initial = [makeSummary(name: "Keep"), makeSummary(name: "Goner")]
        let afterDelete = [makeSummary(name: "Keep")]
        mock.listResult = .success(initial)
        let vm = VirtualPortfoliosListViewModel(api: mock)

        await vm.load()
        guard case .loaded(let before) = vm.state, before.count == 2 else {
            XCTFail("setup: expected 2 loaded, got \(vm.state)")
            return
        }
        mock.listResult = .success(afterDelete)
        await vm.delete(id: pid)

        XCTAssertEqual(mock.deletedIDs, [pid])
        guard case .loaded(let after) = vm.state, after.count == 1 else {
            XCTFail("expected 1 after delete, got \(vm.state)")
            return
        }
        XCTAssertNil(vm.lastError)
    }

    func test_delete_failure_setsLastErrorAndKeepsList() async {
        let mock = MockVirtualPortfolioAPI()
        mock.listResult = .success([makeSummary()])
        let vm = VirtualPortfoliosListViewModel(api: mock)
        await vm.load()
        let beforeState = vm.state

        mock.deleteResult = .failure(VirtualAPIError.forbidden("nope"))
        await vm.delete(id: UUID())

        XCTAssertEqual(vm.state, beforeState, "list should not change on delete failure")
        XCTAssertNotNil(vm.lastError)
        XCTAssertFalse(vm.lastError!.isEmpty)
    }
}
