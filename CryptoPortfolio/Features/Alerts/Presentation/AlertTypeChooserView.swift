import SwiftUI

/// Root of the Create-Alert flow when the user did NOT come from CoinDetail's
/// shortcut. Lets the user pick which kind of alert they want to set up.
struct AlertTypeChooserView: View {
    let container: AppContainer
    let onDone: (Bool) -> Void

    var body: some View {
        List {
            Section("alerts.type.section.coin") {
                NavigationLink {
                    CoinSearchPickerView(container: container) { coin in
                        PriceAlertFormView(coin: coin, container: container, onSave: onDone)
                    }
                } label: {
                    typeRow(systemImage: "arrow.up.circle.fill",
                            titleKey: "alerts.type.priceCrossing",
                            descKey: "alerts.type.priceCrossing.desc")
                }
                NavigationLink {
                    CoinSearchPickerView(container: container) { coin in
                        PercentAlertFormView(coin: coin, container: container, onSave: onDone)
                    }
                } label: {
                    typeRow(systemImage: "chart.line.uptrend.xyaxis",
                            titleKey: "alerts.type.percentChange",
                            descKey: "alerts.type.percentChange.desc")
                }
            }
            Section("alerts.type.section.portfolio") {
                NavigationLink {
                    PortfolioAlertFormView(metric: .value, container: container, onSave: onDone)
                } label: {
                    typeRow(systemImage: "briefcase.fill",
                            titleKey: "alerts.type.portfolioValue",
                            descKey: "alerts.type.portfolioValue.desc")
                }
                NavigationLink {
                    PortfolioAlertFormView(metric: .pnlPercent, container: container, onSave: onDone)
                } label: {
                    typeRow(systemImage: "chart.pie.fill",
                            titleKey: "alerts.type.portfolioPnLPercent",
                            descKey: "alerts.type.portfolioPnLPercent.desc")
                }
            }
        }
        .navigationTitle("alerts.create.chooserTitle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func typeRow(systemImage: String,
                         titleKey: LocalizedStringKey,
                         descKey: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey).font(.body.weight(.semibold))
                Text(descKey).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Inline coin-search step used by the coin-bound alert types. Reuses the
/// search state we already had in CreateAlertViewModel.
struct CoinSearchPickerView<Destination: View>: View {
    let container: AppContainer
    let destination: (Coin) -> Destination

    @StateObject private var viewModel: CreateAlertViewModel

    init(container: AppContainer,
         @ViewBuilder destination: @escaping (Coin) -> Destination) {
        self.container = container
        self.destination = destination
        _viewModel = StateObject(wrappedValue: CreateAlertViewModel(
            searchCoins: container.makeSearchCoinsUseCase()
        ))
    }

    var body: some View {
        content
            .searchable(text: $viewModel.query, prompt: Text("alerts.create.search.prompt"))
            .onSubmit(of: .search) { Task { await viewModel.search() } }
            .navigationTitle("alerts.create.searchTitle")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.results {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(systemImage: "magnifyingglass",
                           titleKey: "alerts.create.empty.title",
                           messageKey: "alerts.create.empty.message")
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.search() } }
        case .loaded(let coins):
            List(coins) { coin in
                NavigationLink {
                    destination(coin)
                } label: {
                    coinRow(coin)
                }
            }
            .listStyle(.plain)
        }
    }

    private func coinRow(_ coin: Coin) -> some View {
        HStack(spacing: 12) {
            if let url = coin.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    default: Circle().fill(.secondary.opacity(0.2))
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle().fill(.secondary.opacity(0.2)).frame(width: 32, height: 32)
            }
            VStack(alignment: .leading) {
                Text(coin.name).font(.body.weight(.semibold))
                Text(coin.symbol.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
