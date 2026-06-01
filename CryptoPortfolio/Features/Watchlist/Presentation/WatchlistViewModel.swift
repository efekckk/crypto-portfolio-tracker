import Foundation

@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[Coin]> = .loading

    private let getWatchlist: GetWatchlistUseCase
    private let toggleWatchlist: ToggleWatchlistUseCase
    let currency: Currency

    init(getWatchlist: GetWatchlistUseCase,
         toggleWatchlist: ToggleWatchlistUseCase,
         currency: Currency = .default) {
        self.getWatchlist = getWatchlist
        self.toggleWatchlist = toggleWatchlist
        self.currency = currency
    }

    func load() async {
        state = .loading
        do {
            let coins = try await getWatchlist(currency: currency)
            state = coins.isEmpty ? .empty : .loaded(coins)
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func refresh() async { await load() }

    func toggle(coinId: String) async {
        do {
            try toggleWatchlist(coinId: coinId)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }
}
