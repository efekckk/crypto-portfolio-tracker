import CoreData

/// Core Data-backed `AlertRepository`. Upserts by id.
final class AlertRepositoryImpl: AlertRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    private var context: NSManagedObjectContext { stack.viewContext }

    func alerts() throws -> [PriceAlert] {
        let request = NSFetchRequest<CDAlert>(entityName: "CDAlert")
        return try context.fetch(request).compactMap(Self.toDomain)
    }

    func alert(id: UUID) throws -> PriceAlert? {
        try fetchEntity(id: id).flatMap(Self.toDomain)
    }

    func save(_ alert: PriceAlert) throws {
        let entity = try fetchEntity(id: alert.id) ?? CDAlert(context: context)
        entity.id = alert.id
        entity.coinId = alert.coinId
        entity.targetPrice = alert.targetPrice
        entity.direction = alert.direction.rawValue
        entity.isActive = alert.isActive
        entity.firedAt = alert.firedAt
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let entity = try fetchEntity(id: id) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - Helpers

    private func fetchEntity(id: UUID) throws -> CDAlert? {
        let request = NSFetchRequest<CDAlert>(entityName: "CDAlert")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func toDomain(_ entity: CDAlert) -> PriceAlert? {
        guard let id = entity.id, let coinId = entity.coinId,
              let rawDirection = entity.direction,
              let direction = PriceAlert.Direction(rawValue: rawDirection)
        else { return nil }
        return PriceAlert(
            id: id,
            coinId: coinId,
            targetPrice: entity.targetPrice,
            direction: direction,
            isActive: entity.isActive,
            firedAt: entity.firedAt
        )
    }
}
