import SwiftUI

/// Tab root for the virtual portfolio feature.
/// Shows the list of portfolios; toolbar "+" opens `NewPortfolioSheet`;
/// tapping a row navigates to `VirtualPortfolioDetailView`; swipe-to-delete
/// calls the VM; pull-to-refresh reloads.
struct VirtualPortfoliosListView: View {
    @StateObject private var viewModel: VirtualPortfoliosListViewModel

    private let api: VirtualPortfolioAPI
    private let container: AppContainer

    @State private var isShowingNewPortfolio = false
    /// Prepended summaries from the NewPortfolioSheet before the next reload
    /// merges them into a clean server-side list.
    @State private var optimisticSummaries: [VirtualPortfolioSummary] = []

    init(api: VirtualPortfolioAPI, container: AppContainer) {
        _viewModel = StateObject(wrappedValue: VirtualPortfoliosListViewModel(api: api))
        self.api = api
        self.container = container
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(
                    String(localized: "virtual.list.title", defaultValue: "Virtual Portfolios")
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingNewPortfolio = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(
                            String(localized: "virtual.list.add.button",
                                   defaultValue: "New portfolio")
                        )
                    }
                }
                .sheet(isPresented: $isShowingNewPortfolio) {
                    NewPortfolioSheet(api: api) { newSummary in
                        optimisticSummaries.insert(newSummary, at: 0)
                    }
                }
                .task { await viewModel.load() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            emptyOrOptimistic

        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }

        case .loaded(let portfolios):
            portfolioList(merging: portfolios)
        }
    }

    /// When the list is empty from the server but the user just created one
    /// (optimistic insert), still show the row so the transition feels instant.
    @ViewBuilder
    private var emptyOrOptimistic: some View {
        if optimisticSummaries.isEmpty {
            EmptyStateView(
                systemImage: "briefcase",
                titleKey: "virtual.list.empty.title",
                messageKey: "virtual.list.empty.message"
            )
        } else {
            portfolioList(merging: [])
        }
    }

    private func portfolioList(merging serverList: [VirtualPortfolioSummary]) -> some View {
        // Deduplicate: optimistic entries that already appear in the server
        // list are dropped so we don't show duplicates after a reload.
        let serverIDs = Set(serverList.map(\.id))
        let merged = optimisticSummaries.filter { !serverIDs.contains($0.id) } + serverList

        return List {
            if let error = viewModel.lastError {
                Section {
                    Text(error)
                        .foregroundStyle(Theme.negative)
                        .font(.subheadline)
                }
            }

            ForEach(merged) { summary in
                NavigationLink {
                    VirtualPortfolioDetailView(
                        portfolioID: summary.id,
                        api: api,
                        container: container
                    )
                } label: {
                    PortfolioSummaryRow(summary: summary)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let id = merged[index].id
                    // Remove from optimistic list immediately for snappy feel
                    optimisticSummaries.removeAll { $0.id == id }
                    Task { await viewModel.delete(id: id) }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.load() }
    }
}

// MARK: - Summary Row

private struct PortfolioSummaryRow: View {
    let summary: VirtualPortfolioSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name)
                    .font(.body.weight(.semibold))
                Text(CurrencyFormatter.format(summary.totalValue, currency: .usd))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PnLBadge(percent: summary.totalPnLPercent)
        }
        .padding(.vertical, 4)
    }
}

private struct PnLBadge: View {
    let percent: Double

    var body: some View {
        Text(CurrencyFormatter.formatPercent(percent))
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.color(forChange: percent))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Theme.color(forChange: percent).opacity(0.12),
                in: Capsule()
            )
    }
}
