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
}
