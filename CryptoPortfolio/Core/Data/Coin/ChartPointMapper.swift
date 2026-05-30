import Foundation

/// Converts a `MarketChartDTO` into the domain `[ChartPoint]`.
enum ChartPointMapper {
    static func map(_ dto: MarketChartDTO) -> [ChartPoint] {
        dto.prices.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            let timestampMs = pair[0]
            let price = pair[1]
            let id = Int(timestampMs)
            let date = Date(timeIntervalSince1970: timestampMs / 1000)
            return ChartPoint(id: id, date: date, price: price)
        }
    }
}
