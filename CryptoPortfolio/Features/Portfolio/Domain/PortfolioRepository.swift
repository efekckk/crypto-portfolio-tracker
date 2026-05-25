import Foundation

/// Persistence for the user's holdings (one per coin id).
protocol PortfolioRepository {
    func holdings() throws -> [Holding]
    func holding(coinId: String) throws -> Holding?
    func save(_ holding: Holding) throws   // upsert by coinId
    func remove(coinId: String) throws
}
