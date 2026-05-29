import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var state: ViewState<PortfolioSummary> = .loading

    private let getSummary: GetPortfolioSummaryUseCase
    private let removeHolding: RemoveHoldingUseCase
    let currency: Currency

    init(getSummary: GetPortfolioSummaryUseCase,
         removeHolding: RemoveHoldingUseCase,
         currency: Currency = .default) {
        self.getSummary = getSummary
        self.removeHolding = removeHolding
        self.currency = currency
    }

    func load() async {
        state = .loading
        do {
            let summary = try await getSummary(currency: currency)
            state = summary.items.isEmpty ? .empty : .loaded(summary)
        } catch {
            state = .error(Self.userFacingMessage(for: error))
        }
    }

    func refresh() async { await load() }

    func delete(coinId: String) async {
        do {
            try removeHolding(coinId: coinId)
            await load()
        } catch {
            state = .error(Self.userFacingMessage(for: error))
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .rateLimited:                  return "Rate limited. Please try again in a moment."
            case .transport(let msg):           return "Network error: \(msg)"
            case .requestFailed(let code):      return "Server error (\(code))."
            case .decoding:                     return "Could not parse server response."
            case .invalidURL:                   return "Invalid request."
            }
        }
        return "Something went wrong."
    }
}
