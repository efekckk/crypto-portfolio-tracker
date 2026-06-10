import XCTest
@testable import CryptoPortfolio

@MainActor
final class VirtualPortfolioDetailViewModelTests: XCTestCase {

    final class MockAPI: VirtualPortfolioAPI {
        var getResult: Result<VirtualPortfolio, Error>!
        var deleteResult: Result<Void, Error> = .success(())
        private(set) var deletedIDs: [UUID] = []
        private(set) var getCalls: Int = 0

        func listPortfolios() async throws -> [VirtualPortfolioSummary] { fatalError("not used") }
        func getPortfolio(id: UUID) async throws -> VirtualPortfolio {
            getCalls += 1
            return try getResult.get()
        }
        func createPortfolio(name: String, startingBalance: Double) async throws -> VirtualPortfolioSummary { fatalError("not used") }
        func deletePortfolio(id: UUID) async throws {
            deletedIDs.append(id)
            try deleteResult.get()
        }
        func quote(portfolioID: UUID, coinID: String) async throws -> VirtualQuote { fatalError("not used") }
        func executeTrade(portfolioID: UUID, side: VirtualTrade.Side, coinID: String, amount: Double) async throws -> VirtualPortfolio { fatalError("not used") }
        func tradeHistory(portfolioID: UUID, beforeID: Int64?, limit: Int) async throws -> VirtualTradeHistoryPage { fatalError("not used") }
    }

    private func makeDetail(name: String = "Test", cash: Double = 10000) -> VirtualPortfolio {
        VirtualPortfolio(
            id: UUID(), name: name, startingBalance: 10000,
            cashBalance: cash, totalValue: cash,
            realizedPnL: 0, unrealizedPnL: 0, totalPnLPercent: 0,
            holdings: [], createdAt: Date(), updatedAt: Date()
        )
    }

    func test_load_success_setsLoaded() async {
        let mock = MockAPI()
        let portfolio = makeDetail(name: "Active")
        mock.getResult = .success(portfolio)
        let vm = VirtualPortfolioDetailViewModel(portfolioID: portfolio.id, api: mock)

        await vm.load()

        guard case .loaded(let loaded) = vm.state else {
            XCTFail("expected .loaded, got \(vm.state)")
            return
        }
        XCTAssertEqual(loaded.name, "Active")
    }

    func test_load_apiError_setsErrorState() async {
        let mock = MockAPI()
        mock.getResult = .failure(VirtualAPIError.notFound("gone"))
        let vm = VirtualPortfolioDetailViewModel(portfolioID: UUID(), api: mock)

        await vm.load()

        guard case .error(let msg) = vm.state else {
            XCTFail("expected .error, got \(vm.state)")
            return
        }
        XCTAssertFalse(msg.isEmpty)
    }

    func test_load_clearsLastError() async {
        let mock = MockAPI()
        mock.getResult = .success(makeDetail())
        let vm = VirtualPortfolioDetailViewModel(portfolioID: UUID(), api: mock)

        // Seed a lastError via a failing delete.
        mock.deleteResult = .failure(VirtualAPIError.forbidden("nope"))
        await vm.delete()
        XCTAssertNotNil(vm.lastError)

        await vm.load()
        XCTAssertNil(vm.lastError)
    }

    func test_delete_success_setsWasDeleted() async {
        let mock = MockAPI()
        mock.getResult = .success(makeDetail())
        let vm = VirtualPortfolioDetailViewModel(portfolioID: UUID(), api: mock)
        await vm.load()

        XCTAssertFalse(vm.wasDeleted)
        await vm.delete()
        XCTAssertTrue(vm.wasDeleted)
        XCTAssertEqual(mock.deletedIDs.count, 1)
    }

    func test_delete_failure_setsLastErrorAndKeepsState() async {
        let mock = MockAPI()
        mock.getResult = .success(makeDetail(name: "Stay"))
        let vm = VirtualPortfolioDetailViewModel(portfolioID: UUID(), api: mock)
        await vm.load()
        let stateBefore = vm.state

        mock.deleteResult = .failure(VirtualAPIError.upstream("down"))
        await vm.delete()

        XCTAssertFalse(vm.wasDeleted)
        XCTAssertEqual(vm.state, stateBefore)
        XCTAssertNotNil(vm.lastError)
        XCTAssertFalse(vm.lastError!.isEmpty)
    }

    func test_applyPostTradeUpdate_setsLoadedDirectlyWithoutAPICall() async {
        let mock = MockAPI()
        mock.getResult = .success(makeDetail(name: "Original", cash: 10000))
        let vm = VirtualPortfolioDetailViewModel(portfolioID: UUID(), api: mock)
        await vm.load()
        XCTAssertEqual(mock.getCalls, 1)

        // Hand the VM a post-trade snapshot.
        let updated = makeDetail(name: "Updated", cash: 5000)
        vm.applyPostTradeUpdate(updated)

        guard case .loaded(let loaded) = vm.state else {
            XCTFail("expected .loaded, got \(vm.state)")
            return
        }
        XCTAssertEqual(loaded.name, "Updated")
        XCTAssertEqual(loaded.cashBalance, 5000)
        XCTAssertEqual(mock.getCalls, 1, "applyPostTradeUpdate should NOT trigger a new GET")
    }
}
