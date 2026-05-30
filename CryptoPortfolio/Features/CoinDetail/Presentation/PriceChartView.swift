import SwiftUI
import Charts

struct PriceChartView: View {
    let points: [ChartPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("date", point.date),
                y: .value("price", point.price)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Theme.accent)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
    }
}
