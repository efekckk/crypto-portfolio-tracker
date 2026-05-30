import Foundation

/// A single (time, price) sample for a performance chart. `id` is the source
/// timestamp in milliseconds, kept stable across reloads.
struct ChartPoint: Identifiable, Equatable {
    let id: Int
    let date: Date
    let price: Double
}
