import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel
    private let container: AppContainer
    @State private var isShowingCreate = false

    init(container: AppContainer, currency: Currency = .default) {
        self.container = container
        _viewModel = StateObject(wrappedValue: AlertsViewModel(
            getAlerts: container.makeGetAlertsUseCase(),
            deleteAlert: container.makeDeleteAlertUseCase(),
            setActive: container.makeSetAlertActiveUseCase(),
            evaluate: container.makeEvaluateAlertsUseCase(currency: currency),
            notifications: container.notifications,
            currency: currency
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("alerts.title")
                .toolbar { trailingToolbar }
                .refreshable { await viewModel.evaluateNow() }
                .task {
                    await viewModel.requestNotificationPermission()
                    await viewModel.load()
                    await viewModel.evaluateNow()
                }
                .sheet(isPresented: $isShowingCreate) {
                    CreateAlertView(container: container) { didCreate in
                        isShowingCreate = false
                        if didCreate {
                            Task {
                                await viewModel.load()
                                await viewModel.evaluateNow()
                            }
                        }
                    }
                }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isShowingCreate = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("alerts.create.accessibility")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                systemImage: "bell.slash",
                titleKey: "alerts.empty.title",
                messageKey: "alerts.empty.message"
            )
        case .error(let message):
            ErrorStateView(message: message) { Task { await viewModel.load() } }
        case .loaded(let alerts):
            loadedList(alerts: alerts)
        }
    }

    private func loadedList(alerts: [PriceAlert]) -> some View {
        List {
            ForEach(alerts) { alert in
                AlertRow(alert: alert, currency: .default) { newValue in
                    Task { await viewModel.setActive(id: alert.id, isActive: newValue) }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(id: alert.id) }
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
