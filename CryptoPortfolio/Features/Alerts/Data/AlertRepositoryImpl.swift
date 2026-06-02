import CoreData

/// Core Data-backed `AlertRepository`. Upserts by id. Persists the polymorphic
/// `AlertCondition` and `Recurrence` as JSON in dedicated columns; falls back
/// to the legacy `(coinId, targetPrice, direction)` columns when a row was
/// written by v1.0 of the app.
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
        entity.isActive = alert.isActive
        entity.firedAt = alert.firedAt
        entity.conditionJSON = try Self.encodeJSON(alert.condition)
        entity.recurrenceJSON = try Self.encodeJSON(alert.recurrence)
        entity.lastConditionResult = alert.lastConditionResult.map { NSNumber(value: $0) }
        // Mirror legacy columns for .priceCrossing variants so Core Data dumps
        // / future v1.x queries stay readable. Other variants leave them at
        // sentinel values that the legacy decoder would interpret as "above 0",
        // but we never fall back to those columns when conditionJSON is present.
        switch alert.condition {
        case .priceCrossing(let coinId, let direction, let targetPrice):
            entity.coinId = coinId
            entity.targetPrice = targetPrice
            entity.direction = direction.rawValue
        case .percentChange, .portfolioValue, .portfolioPnLPercent:
            entity.coinId = nil
            entity.targetPrice = 0
            entity.direction = "above"
        }
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

    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try jsonEncoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String?) -> T? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? jsonDecoder.decode(T.self, from: data)
    }

    private static func toDomain(_ entity: CDAlert) -> PriceAlert? {
        guard let id = entity.id else { return nil }
        let condition: AlertCondition
        if let parsed = decode(AlertCondition.self, from: entity.conditionJSON) {
            condition = parsed
        } else {
            // Legacy row: synthesise .priceCrossing from the v1 columns.
            guard let coinId = entity.coinId,
                  let rawDirection = entity.direction,
                  let direction = AlertCondition.Direction(rawValue: rawDirection)
            else { return nil }
            condition = .priceCrossing(coinId: coinId, direction: direction, targetPrice: entity.targetPrice)
        }
        let recurrence = decode(Recurrence.self, from: entity.recurrenceJSON) ?? .oneShot
        return PriceAlert(
            id: id,
            condition: condition,
            recurrence: recurrence,
            isActive: entity.isActive,
            firedAt: entity.firedAt,
            lastConditionResult: entity.lastConditionResult?.boolValue
        )
    }
}
