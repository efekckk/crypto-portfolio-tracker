import CoreData

/// Core Data-backed `WatchlistRepository`. Idempotent add (one row per coinId).
final class WatchlistRepositoryImpl: WatchlistRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    private var context: NSManagedObjectContext { stack.viewContext }

    func items() throws -> [WatchItem] {
        let request = NSFetchRequest<CDWatchItem>(entityName: "CDWatchItem")
        request.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: true)]
        return try context.fetch(request).map(Self.toDomain)
    }

    func isWatched(coinId: String) throws -> Bool {
        try fetchEntity(coinId: coinId) != nil
    }

    func add(coinId: String) throws {
        if try fetchEntity(coinId: coinId) != nil { return }
        let entity = CDWatchItem(context: context)
        entity.coinId = coinId
        entity.addedAt = Date()
        try context.save()
    }

    func remove(coinId: String) throws {
        guard let entity = try fetchEntity(coinId: coinId) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - Helpers

    private func fetchEntity(coinId: String) throws -> CDWatchItem? {
        let request = NSFetchRequest<CDWatchItem>(entityName: "CDWatchItem")
        request.predicate = NSPredicate(format: "coinId == %@", coinId)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func toDomain(_ entity: CDWatchItem) -> WatchItem {
        WatchItem(coinId: entity.coinId ?? "", addedAt: entity.addedAt ?? Date())
    }
}
