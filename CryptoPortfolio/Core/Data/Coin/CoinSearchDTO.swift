import Foundation

/// CoinGecko `/search` response (only the `coins` array is used).
struct CoinSearchResponseDTO: Decodable {
    let coins: [CoinSearchItemDTO]
}

struct CoinSearchItemDTO: Decodable {
    let id: String
    let name: String
    let symbol: String
    let thumb: String?
    let large: String?
}
