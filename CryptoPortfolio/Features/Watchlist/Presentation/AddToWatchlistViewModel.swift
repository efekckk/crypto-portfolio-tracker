import Foundation

@MainActor
final class AddToWatchlistViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty
    @Published private(set) var watchedIds: Set<String> = []

    private let searchCoins: SearchCoinsUseCase
    private let toggleWatchlist: ToggleWatchlistUseCase
    private let watchlistRepository: WatchlistRepository

    init(searchCoins: SearchCoinsUseCase,
         toggleWatchlist: ToggleWatchlistUseCase,
         watchlistRepository: WatchlistRepository) {
        self.searchCoins = searchCoins
        self.toggleWatchlist = toggleWatchlist
        self.watchlistRepository = watchlistRepository
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { results = .empty; return }
        results = .loading
        do {
            let coins = try await searchCoins(trimmed)
            results = coins.isEmpty ? .empty : .loaded(coins)
        } catch {
            results = .error(error.userFacingMessage)
        }
    }

    func refreshWatchedIds() async {
        do {
            let items = try watchlistRepository.items()
            watchedIds = Set(items.map(\.coinId))
        } catch {
            watchedIds = []
        }
    }

    func isWatched(coinId: String) -> Bool { watchedIds.contains(coinId) }

    func toggle(coinId: String) async {
        do {
            try toggleWatchlist(coinId: coinId)
            await refreshWatchedIds()
        } catch {
            // No state slot for inline errors here; ignored at the VM layer for v1.
            // A future enhancement could expose a toast or `.error` field.
        }
    }
}
