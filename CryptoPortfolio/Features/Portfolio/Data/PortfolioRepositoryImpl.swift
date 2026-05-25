import CoreData

/// Core Data-backed `PortfolioRepository`. Upserts by `coinId`.
final class PortfolioRepositoryImpl: PortfolioRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    private var context: NSManagedObjectContext { stack.viewContext }

    func holdings() throws -> [Holding] {
        let request = NSFetchRequest<CDHolding>(entityName: "CDHolding")
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: true)]
        return try context.fetch(request).map(Self.toDomain)
    }

    func holding(coinId: String) throws -> Holding? {
        try fetchEntity(coinId: coinId).map(Self.toDomain)
    }

    func save(_ holding: Holding) throws {
        let entity = try fetchEntity(coinId: holding.coinId) ?? CDHolding(context: context)
        entity.coinId = holding.coinId
        entity.amount = holding.amount
        entity.averageBuyPrice = holding.averageBuyPrice
        entity.dateAdded = holding.dateAdded
        try context.save()
    }

    func remove(coinId: String) throws {
        guard let entity = try fetchEntity(coinId: coinId) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - Helpers

    private func fetchEntity(coinId: String) throws -> CDHolding? {
        let request = NSFetchRequest<CDHolding>(entityName: "CDHolding")
        request.predicate = NSPredicate(format: "coinId == %@", coinId)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func toDomain(_ entity: CDHolding) -> Holding {
        Holding(
            coinId: entity.coinId ?? "",
            amount: entity.amount,
            averageBuyPrice: entity.averageBuyPrice,
            dateAdded: entity.dateAdded ?? Date()
        )
    }
}
