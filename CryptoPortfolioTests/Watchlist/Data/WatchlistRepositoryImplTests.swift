import XCTest
@testable import CryptoPortfolio

final class WatchlistRepositoryImplTests: XCTestCase {
    private func makeSUT() -> WatchlistRepositoryImpl {
        WatchlistRepositoryImpl(stack: CoreDataStack(inMemory: true))
    }

    func test_items_startsEmpty() throws {
        let sut = makeSUT()
        XCTAssertTrue(try sut.items().isEmpty)
    }

    func test_add_thenItems_returnsWatchedCoin() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")

        let items = try sut.items()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.coinId, "bitcoin")
    }

    func test_add_isIdempotentForSameCoinId() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")
        try sut.add(coinId: "bitcoin")

        let items = try sut.items()

        XCTAssertEqual(items.count, 1, "Same coinId must not duplicate")
    }

    func test_isWatched_returnsTrueForAdded_andFalseForUnknown() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")

        XCTAssertTrue(try sut.isWatched(coinId: "bitcoin"))
        XCTAssertFalse(try sut.isWatched(coinId: "ethereum"))
    }

    func test_remove_deletesItem() throws {
        let sut = makeSUT()
        try sut.add(coinId: "bitcoin")
        try sut.add(coinId: "ethereum")

        try sut.remove(coinId: "bitcoin")

        XCTAssertEqual(try sut.items().map(\.coinId), ["ethereum"])
    }

    func test_items_sortedByAddedAtAscending() throws {
        let sut = makeSUT()
        try sut.add(coinId: "a")
        Thread.sleep(forTimeInterval: 0.01)
        try sut.add(coinId: "b")

        let order = try sut.items().map(\.coinId)
        XCTAssertEqual(order, ["a", "b"])
    }
}
