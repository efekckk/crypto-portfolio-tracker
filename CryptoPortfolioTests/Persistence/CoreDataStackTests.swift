import XCTest
import CoreData
@testable import CryptoPortfolio

final class CoreDataStackTests: XCTestCase {
    func test_inMemoryStack_savesAndFetchesCachedCoin() throws {
        let stack = CoreDataStack(inMemory: true)
        let context = stack.viewContext

        let coin = CDCachedCoin(context: context)
        coin.id = "bitcoin"
        coin.symbol = "btc"
        coin.name = "Bitcoin"
        coin.currentPrice = 50_000
        coin.priceChangePercentage24h = 2.5
        coin.updatedAt = Date()
        try context.save()

        let request = NSFetchRequest<CDCachedCoin>(entityName: "CDCachedCoin")
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "bitcoin")
        XCTAssertEqual(results.first?.currentPrice, 50_000)
    }

    func test_inMemoryStack_startsEmpty() throws {
        let stack = CoreDataStack(inMemory: true)
        let request = NSFetchRequest<CDCachedCoin>(entityName: "CDCachedCoin")
        let results = try stack.viewContext.fetch(request)
        XCTAssertEqual(results.count, 0)
    }

    func test_savingSecondCoinWithSameID_upsertsToSingleRowWithNewValues() throws {
        let stack = CoreDataStack(inMemory: true)
        let context = stack.viewContext

        // First insert + save commits "bitcoin" at 50_000 to the store.
        let first = CDCachedCoin(context: context)
        first.id = "bitcoin"
        first.currentPrice = 50_000
        first.updatedAt = Date()
        try context.save()

        // A fresh object with the SAME id should upsert (uniqueness constraint +
        // ObjectTrump merge policy => new values win), not create a duplicate.
        let second = CDCachedCoin(context: context)
        second.id = "bitcoin"
        second.currentPrice = 60_000
        second.updatedAt = Date()
        try context.save()

        let request = NSFetchRequest<CDCachedCoin>(entityName: "CDCachedCoin")
        let results = try context.fetch(request)

        XCTAssertEqual(results.count, 1, "Uniqueness constraint on id must prevent duplicates")
        XCTAssertEqual(results.first?.currentPrice, 60_000, "ObjectTrump policy: newest values win")
    }

    func test_savedCoin_persistsUpdatedAt() throws {
        let stack = CoreDataStack(inMemory: true)
        let context = stack.viewContext
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let coin = CDCachedCoin(context: context)
        coin.id = "ethereum"
        coin.currentPrice = 3_000
        coin.updatedAt = timestamp
        try context.save()

        let request = NSFetchRequest<CDCachedCoin>(entityName: "CDCachedCoin")
        let results = try context.fetch(request)

        XCTAssertEqual(results.first?.updatedAt, timestamp)
    }
}
