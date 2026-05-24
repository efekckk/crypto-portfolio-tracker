import Foundation

/// A single (time, price) sample for a performance chart.
struct ChartPoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let price: Double
}
