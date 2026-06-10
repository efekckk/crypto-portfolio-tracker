import XCTest
@testable import CryptoPortfolio

@MainActor
final class NewPortfolioViewModelTests: XCTestCase {

    final class MockAPI: VirtualPortfolioAPI {
        var createResult: Result<VirtualPortfolioSummary, Error>!
        private(set) var createRequests: [(name: String, balance: Double)] = []

        func listPortfolios() async throws -> [VirtualPortfolioSummary] { fatalError("not used") }
        func getPortfolio(id: UUID) async throws -> VirtualPortfolio { fatalError("not used") }
        func createPortfolio(name: String, startingBalance: Double) async throws -> VirtualPortfolioSummary {
            createRequests.append((name, startingBalance))
            return try createResult.get()
        }
        func deletePortfolio(id: UUID) async throws { fatalError("not used") }
        func quote(portfolioID: UUID, coinID: String) async throws -> VirtualQuote { fatalError("not used") }
        func executeTrade(portfolioID: UUID, side: VirtualTrade.Side, coinID: String, amount: Double) async throws -> VirtualPortfolio { fatalError("not used") }
        func tradeHistory(portfolioID: UUID, beforeID: Int64?, limit: Int) async throws -> VirtualTradeHistoryPage { fatalError("not used") }
    }

    private func makeSummary(name: String = "P1", balance: Double = 10_000) -> VirtualPortfolioSummary {
        VirtualPortfolioSummary(
            id: UUID(),
            name: name,
            startingBalance: balance,
            cashBalance: balance,
            totalValue: balance,
            totalPnL: 0,
            totalPnLPercent: 0,
            tradeCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Presets

    func test_resolvedBalance_k1_returns1000() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .k1
        XCTAssertEqual(vm.resolvedBalance, 1_000)
    }

    func test_resolvedBalance_k10_returns10000() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .k10
        XCTAssertEqual(vm.resolvedBalance, 10_000)
    }

    func test_resolvedBalance_k100_returns100000() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .k100
        XCTAssertEqual(vm.resolvedBalance, 100_000)
    }

    func test_resolvedBalance_custom_parsesAmount() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .custom
        vm.customBalanceText = "2500"
        XCTAssertEqual(vm.resolvedBalance, 2_500)
    }

    func test_resolvedBalance_custom_commaDecimal_isNormalized() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .custom
        vm.customBalanceText = "1500,5"
        XCTAssertEqual(vm.resolvedBalance, 1_500.5)
    }

    func test_resolvedBalance_custom_empty_isNil() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .custom
        vm.customBalanceText = ""
        XCTAssertNil(vm.resolvedBalance)
    }

    func test_resolvedBalance_custom_zero_isNil() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .custom
        vm.customBalanceText = "0"
        XCTAssertNil(vm.resolvedBalance)
    }

    // MARK: - canSave

    func test_canSave_requiresNameAndBalance() {
        let vm = NewPortfolioViewModel(api: MockAPI())

        // empty name
        vm.nameText = ""
        vm.balancePreset = .k10
        XCTAssertFalse(vm.canSave)

        // whitespace-only name
        vm.nameText = "   "
        XCTAssertFalse(vm.canSave)

        // valid name + preset
        vm.nameText = "My Portfolio"
        XCTAssertTrue(vm.canSave)

        // custom preset with empty balance
        vm.balancePreset = .custom
        vm.customBalanceText = ""
        XCTAssertFalse(vm.canSave)

        // custom preset with valid balance
        vm.customBalanceText = "5000"
        XCTAssertTrue(vm.canSave)
    }

    func test_canSave_rejectsNamesOver50Chars() {
        let vm = NewPortfolioViewModel(api: MockAPI())
        vm.balancePreset = .k10
        vm.nameText = String(repeating: "a", count: 51)
        XCTAssertFalse(vm.canSave)

        vm.nameText = String(repeating: "a", count: 50)
        XCTAssertTrue(vm.canSave)
    }

    // MARK: - save

    func test_save_happyPath_returnsCreatedSummary() async {
        let mock = MockAPI()
        let expected = makeSummary(name: "Trading", balance: 10_000)
        mock.createResult = .success(expected)
        let vm = NewPortfolioViewModel(api: mock)
        vm.nameText = "  Trading  "
        vm.balancePreset = .k10

        let result = await vm.save()

        XCTAssertEqual(result?.id, expected.id)
        XCTAssertEqual(mock.createRequests.count, 1)
        XCTAssertEqual(mock.createRequests[0].name, "Trading") // trimmed
        XCTAssertEqual(mock.createRequests[0].balance, 10_000)
        XCTAssertNil(vm.saveError)
    }

    func test_save_invalidName_setsErrorWithoutAPICall() async {
        let mock = MockAPI()
        let vm = NewPortfolioViewModel(api: mock)
        vm.nameText = ""
        vm.balancePreset = .k10

        let result = await vm.save()

        XCTAssertNil(result)
        XCTAssertNotNil(vm.saveError)
        XCTAssertEqual(mock.createRequests.count, 0)
    }

    func test_save_conflict_localizesNameTaken() async {
        let mock = MockAPI()
        mock.createResult = .failure(VirtualAPIError.conflict("name already exists"))
        let vm = NewPortfolioViewModel(api: mock)
        vm.nameText = "Dup"
        vm.balancePreset = .k10

        let result = await vm.save()

        XCTAssertNil(result)
        XCTAssertEqual(vm.saveError,
            String(localized: "virtual.new.error.name_taken",
                   defaultValue: "A portfolio with this name already exists."))
    }

    func test_save_otherError_fallsBackToGenericMessage() async {
        let mock = MockAPI()
        mock.createResult = .failure(VirtualAPIError.upstream("down"))
        let vm = NewPortfolioViewModel(api: mock)
        vm.nameText = "X"
        vm.balancePreset = .k10

        _ = await vm.save()

        XCTAssertNotNil(vm.saveError)
        XCTAssertFalse(vm.saveError!.isEmpty)
    }
}
