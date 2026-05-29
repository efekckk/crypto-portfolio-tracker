import SwiftUI

struct RootView: View {
    @Environment(\.appContainer) private var container

    var body: some View {
        TabView {
            PortfolioView(
                getSummary: container.makeGetPortfolioSummaryUseCase(),
                removeHolding: container.makeRemoveHoldingUseCase()
            )
            .tabItem { Label("tab.portfolio", systemImage: "chart.pie.fill") }

            PlaceholderTab(titleKey: "tab.watchlist", systemImage: "star.fill")
                .tabItem { Label("tab.watchlist", systemImage: "star.fill") }

            PlaceholderTab(titleKey: "tab.alerts", systemImage: "bell.fill")
                .tabItem { Label("tab.alerts", systemImage: "bell.fill") }
        }
    }
}

private struct PlaceholderTab: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(titleKey)
                .font(.title2.bold())
            Text("common.comingSoon")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
