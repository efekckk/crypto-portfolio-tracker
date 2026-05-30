import Foundation

/// Subset of CoinGecko `/coins/{id}/market_chart` (only `prices` is consumed).
/// Each price entry is `[timestamp_ms, price]`.
struct MarketChartDTO: Decodable, Equatable {
    let prices: [[Double]]
}
