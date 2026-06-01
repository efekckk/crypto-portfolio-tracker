import Foundation

/// Persistence for price alerts (one row per id).
protocol AlertRepository {
    func alerts() throws -> [PriceAlert]
    func alert(id: UUID) throws -> PriceAlert?
    func save(_ alert: PriceAlert) throws   // upsert by id
    func delete(id: UUID) throws
}
