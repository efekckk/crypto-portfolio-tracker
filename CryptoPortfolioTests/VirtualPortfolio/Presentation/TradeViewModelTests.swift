import XCTest
@testable import CryptoPortfolio

@MainActor
final class TradeViewModelTests: XCTestCase {

    final class MockAPI: VirtualPortfolioAPI {
        var quoteResult: Result<VirtualQuote, Error>!
        var executeResult: Result<VirtualPortfolio, Error>!
        private(set) var quoteCalls: Int = 0
        private(set) var executedRequests: [(side: VirtualTrade.Side, coinID: String, amount: Double)] = []

        func listPortfolios() async throws -> [VirtualPortfolioSummary] { fatalError("not used") }
        func getPortfolio(id: UUID) async throws -> VirtualPortfolio { fatalError("not used") }
        func createPortfolio(name: String, startingBalance: Double) async throws -> VirtualPortfolioSummary { fatalError("not used") }
        func deletePortfolio(id: UUID) async throws { fatalError("not used") }
        func quote(portfolioID: UUID, coinID: String) async throws -> VirtualQuote {
            quoteCalls += 1
            return try quoteResult.get()
        }
        func executeTrade(portfolioID: UUID, side: VirtualTrade.Side, coinID: String, amount: Double) async throws -> VirtualPortfolio {
            executedRequests.append((side, coinID, amount))
            return try executeResult.get()
        }
        func tradeHistory(portfolioID: UUID, beforeID: Int64?, limit: Int) async throws -> VirtualTradeHistoryPage { fatalError("not used") }
    }

    private func makeQuote(price: Double = 80000, maxBuy: Double = 0.125, maxSell: Double = 0) -> VirtualQuote {
        VirtualQuote(coinId: "bitcoin", coinName: "Bitcoin",
                     price: price, fetchedAt: Date(),
                     maxBuyAmount: maxBuy, maxSellAmount: maxSell)
    }

    private func makePortfolio(cash: Double = 6000) -> VirtualPortfolio {
        VirtualPortfolio(
            id: UUID(), name: "P", startingBalance: 10000,
            cashBalance: cash, totalValue: 10000,
            realizedPnL: 0, unrealizedPnL: 0, totalPnLPercent: 0,
            holdings: [], createdAt: Date(), updatedAt: Date()
        )
    }

    private func makeVM(_ mock: MockAPI) -> TradeViewModel {
        TradeViewModel(portfolioID: UUID(), coinID: "bitcoin",
                       coinName: "Bitcoin", api: mock)
    }

    // MARK: - Quote

    func test_refreshQuote_success_setsLoaded() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote())
        let vm = makeVM(mock)
        await vm.refreshQuote()
        guard case .loaded(let q) = vm.quoteState else {
            XCTFail("expected .loaded, got \(vm.quoteState)")
            return
        }
        XCTAssertEqual(q.price, 80000)
    }

    func test_refreshQuote_error_setsErrorState() async {
        let mock = MockAPI()
        mock.quoteResult = .failure(VirtualAPIError.upstream("down"))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        guard case .error(let msg) = vm.quoteState else {
            XCTFail("expected .error")
            return
        }
        XCTAssertFalse(msg.isEmpty)
    }

    // MARK: - Amount + total cost

    func test_setMaxAmount_buy_fillsMaxBuy() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(price: 100, maxBuy: 1.5))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.side = .buy
        vm.setMaxAmount()
        XCTAssertEqual(vm.amountText, "1.5")
    }

    func test_setMaxAmount_sell_fillsMaxSell() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(maxSell: 0.25))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.side = .sell
        vm.setMaxAmount()
        XCTAssertEqual(vm.amountText, "0.25")
    }

    func test_setMaxAmount_noQuote_doesNothing() async {
        let mock = MockAPI()
        let vm = makeVM(mock)
        vm.amountText = "0.05"
        vm.setMaxAmount() // quoteState is .loading, no-op
        XCTAssertEqual(vm.amountText, "0.05")
    }

    func test_amountText_commaDecimal_isNormalized() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(price: 100))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.amountText = "0,5"
        XCTAssertEqual(vm.totalCost, 50)
    }

    func test_totalCost_recomputesOnAmountChange() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(price: 100))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.amountText = "0.5"
        XCTAssertEqual(vm.totalCost, 50)
        vm.amountText = "1.0"
        XCTAssertEqual(vm.totalCost, 100)
    }

    // MARK: - canSubmit

    func test_canSubmit_requiresPositiveAmountWithinCap() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(maxBuy: 0.1))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.side = .buy

        vm.amountText = ""
        XCTAssertFalse(vm.canSubmit)

        vm.amountText = "0"
        XCTAssertFalse(vm.canSubmit)

        vm.amountText = "0.05"
        XCTAssertTrue(vm.canSubmit)

        vm.amountText = "0.2" // over cap
        XCTAssertFalse(vm.canSubmit)
    }

    // MARK: - Confirm

    func test_confirm_happyPath_returnsPostTradePortfolio() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(maxBuy: 1.0))
        let expected = makePortfolio(cash: 6000)
        mock.executeResult = .success(expected)
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.amountText = "0.05"

        let result = await vm.confirm()

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.cashBalance, expected.cashBalance)
        XCTAssertEqual(mock.executedRequests.count, 1)
        XCTAssertEqual(mock.executedRequests[0].amount, 0.05)
    }

    func test_confirm_invalidAmount_setsSaveErrorWithoutAPICall() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote())
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.amountText = "abc"

        let result = await vm.confirm()

        XCTAssertNil(result)
        XCTAssertNotNil(vm.saveError)
        XCTAssertEqual(mock.executedRequests.count, 0)
    }

    func test_confirm_insufficientCash_localizesSaveError() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(maxBuy: 1.0))
        mock.executeResult = .failure(VirtualAPIError.unprocessable("insufficient_cash"))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.amountText = "0.5"

        let result = await vm.confirm()

        XCTAssertNil(result)
        XCTAssertEqual(vm.saveError,
            String(localized: "virtual.trade.error.insufficient_cash",
                   defaultValue: "Not enough cash for this trade."))
    }

    func test_confirm_insufficientHoldings_localizesSaveError() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(maxSell: 1.0))
        mock.executeResult = .failure(VirtualAPIError.unprocessable("insufficient_holdings"))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.side = .sell
        vm.amountText = "0.5"

        let result = await vm.confirm()

        XCTAssertNil(result)
        XCTAssertEqual(vm.saveError,
            String(localized: "virtual.trade.error.insufficient_holdings",
                   defaultValue: "Not enough holdings to sell."))
    }

    func test_confirm_otherUnprocessable_fallsBackToGenericMessage() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(maxBuy: 1.0))
        mock.executeResult = .failure(VirtualAPIError.unprocessable("coin not found in markets snapshot"))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.amountText = "0.5"

        _ = await vm.confirm()

        XCTAssertNotNil(vm.saveError)
        XCTAssertFalse(vm.saveError!.isEmpty)
    }

    func test_confirm_upstream_setsSaveError() async {
        let mock = MockAPI()
        mock.quoteResult = .success(makeQuote(maxBuy: 1.0))
        mock.executeResult = .failure(VirtualAPIError.upstream("down"))
        let vm = makeVM(mock)
        await vm.refreshQuote()
        vm.amountText = "0.05"

        _ = await vm.confirm()

        XCTAssertNotNil(vm.saveError)
    }
}
