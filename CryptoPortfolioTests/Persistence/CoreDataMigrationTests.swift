import XCTest
import CoreData
@testable import CryptoPortfolio

final class CoreDataMigrationTests: XCTestCase {
    func test_freshStore_hasV2Attributes_onCDAlert() throws {
        let stack = CoreDataStack(inMemory: true)
        let entity = NSEntityDescription.entity(forEntityName: "CDAlert",
                                                in: stack.viewContext)
        XCTAssertNotNil(entity)
        let attrs = entity?.attributesByName ?? [:]
        XCTAssertTrue(attrs["conditionJSON"] != nil)
        XCTAssertTrue(attrs["recurrenceJSON"] != nil)
        XCTAssertTrue(attrs["lastConditionResult"] != nil)
        // coinId is optional in v2 because portfolio-level alerts
        // (.portfolioValue / .portfolioPnLPercent) aren't tied to a single coin.
        XCTAssertEqual(attrs["coinId"]?.isOptional, true)
    }
}
