import SwiftUI

// MARK: - Private ViewModel

@MainActor
private final class CoinPickerViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: ViewState<[Coin]> = .empty

    private let searchCoins: SearchCoinsUseCase

    init(searchCoins: SearchCoinsUseCase) {
        self.searchCoins = searchCoins
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = .empty
            return
        }
        results = .loading
        do {
            let coins = try await searchCoins(trimmed)
            results = coins.isEmpty ? .empty : .loaded(coins)
        } catch {
            results = .error(error.localizedDescription)
        }
    }
}

// MARK: - View

/// Lightweight coin search sheet used by the virtual trade flow.
/// On selection the chosen `Coin` is delivered via `onSelect` and the sheet
/// dismisses itself.
struct VirtualCoinPickerSheet: View {
    @StateObject private var viewModel: CoinPickerViewModel
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Coin) -> Void

    init(container: AppContainer, onSelect: @escaping (Coin) -> Void) {
        _viewModel = StateObject(wrappedValue: CoinPickerViewModel(
            searchCoins: container.makeSearchCoinsUseCase()
        ))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(
                    String(localized: "virtual.trade.coinpicker.title",
                           defaultValue: "Select a Coin")
                )
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $viewModel.query,
                    prompt: Text(
                        String(localized: "virtual.trade.coinpicker.prompt",
                               defaultValue: "Search coins…")
                    )
                )
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(
                            String(localized: "common.cancel", defaultValue: "Cancel")
                        ) { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.results {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            EmptyStateView(
                systemImage: "magnifyingglass",
                titleKey: "virtual.trade.coinpicker.empty.title",
                messageKey: "virtual.trade.coinpicker.empty.message"
            )

        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }

        case .loaded(let coins):
            List(coins) { coin in
                Button {
                    onSelect(coin)
                    dismiss()
                } label: {
                    CoinPickerRow(coin: coin)
                }
                .foregroundStyle(.primary)
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Row

private struct CoinPickerRow: View {
    let coin: Coin

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = coin.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            Circle().fill(.secondary.opacity(0.2))
                        }
                    }
                } else {
                    Circle().fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name)
                    .font(.body.weight(.semibold))
                Text(coin.symbol.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
