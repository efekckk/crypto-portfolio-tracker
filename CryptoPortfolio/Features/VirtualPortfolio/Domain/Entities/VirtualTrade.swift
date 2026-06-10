import Foundation

/// A single executed buy or sell. Amount is always positive; direction is
/// encoded by Side. Price is the USD per unit at fill time.
struct VirtualTrade: Identifiable, Equatable {
    enum Side: String, Codable, Equatable {
        case buy
        case sell
    }

    let id: Int64
    let side: Side
    let coinId: String
    let amount: Double
    let price: Double
    let executedAt: Date
}

/// One page of trade history returned by the cursor-paginated endpoint.
struct VirtualTradeHistoryPage: Equatable {
    let trades: [VirtualTrade]
    let nextCursor: Int64?
}
