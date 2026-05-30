import Foundation

/// CoinGecko-backed `CoinRepository`.
final class CoinRepositoryImpl: CoinRepository {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    func searchCoins(query: String) async throws -> [Coin] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: CoinSearchResponseDTO = try await httpClient.send(
            CoinGeckoEndpoints.search(query: trimmed), as: CoinSearchResponseDTO.self
        )
        return response.coins.map(CoinMapper.map)
    }

    func markets(ids: [String], currency: Currency) async throws -> [Coin] {
        guard !ids.isEmpty else { return [] }
        let dtos: [CoinMarketDTO] = try await httpClient.send(
            CoinGeckoEndpoints.markets(ids: ids, vsCurrency: currency.code), as: [CoinMarketDTO].self
        )
        return dtos.map(CoinMapper.map)
    }
}
