import XCTest
import CoreData
@testable import CryptoPortfolio

final class PortfolioRepositoryImplTests: XCTestCase {
    private func makeSUT() -> PortfolioRepositoryImpl {
        PortfolioRepositoryImpl(stack: CoreDataStack(inMemory: true))
    }

    func test_holdings_startsEmpty() throws {
        let sut = makeSUT()
        XCTAssertTrue(try sut.holdings().isEmpty)
    }

    func test_save_thenHoldings_returnsSavedHolding() throws {
        let sut = makeSUT()
        try sut.save(Holding(coinId: "bitcoin", amount: 2, averageBuyPrice: 40000,
                             dateAdded: Date(timeIntervalSince1970: 1000)))

        let holdings = try sut.holdings()

        XCTAssertEqual(holdings.count, 1)
        XCTAssertEqual(holdings.first?.coinId, "bitcoin")
        XCTAssertEqual(holdings.first?.amount, 2)
        XCTAssertEqual(holdings.first?.averageBuyPrice, 40000)
    }

    func test_save_withSameCoinId_updatesInsteadOfDuplicating() throws {
        let sut = makeSUT()
        try sut.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 30000))
        try sut.save(Holding(coinId: "bitcoin", amount: 3, averageBuyPrice: 45000))

        let holdings = try sut.holdings()

        XCTAssertEqual(holdings.count, 1, "Same coinId must update, not duplicate")
        XCTAssertEqual(holdings.first?.amount, 3)
        XCTAssertEqual(holdings.first?.averageBuyPrice, 45000)
    }

    func test_holding_returnsNilWhenAbsent_andValueWhenPresent() throws {
        let sut = makeSUT()
        XCTAssertNil(try sut.holding(coinId: "bitcoin"))

        try sut.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100))

        XCTAssertEqual(try sut.holding(coinId: "bitcoin")?.amount, 1)
    }

    func test_remove_deletesHolding() throws {
        let sut = makeSUT()
        try sut.save(Holding(coinId: "bitcoin", amount: 1, averageBuyPrice: 100))
        try sut.save(Holding(coinId: "ethereum", amount: 5, averageBuyPrice: 2000))

        try sut.remove(coinId: "bitcoin")

        let holdings = try sut.holdings()
        XCTAssertEqual(holdings.map(\.coinId), ["ethereum"])
    }
}
