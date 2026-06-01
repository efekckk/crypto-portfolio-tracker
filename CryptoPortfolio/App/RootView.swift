import SwiftUI

struct RootView: View {
    @Environment(\.appContainer) private var container

    var body: some View {
        TabView {
            PortfolioView(container: container)
                .tabItem { Label("tab.portfolio", systemImage: "chart.pie.fill") }

            WatchlistView(container: container)
                .tabItem { Label("tab.watchlist", systemImage: "star.fill") }

            AlertsView(container: container)
                .tabItem { Label("tab.alerts", systemImage: "bell.fill") }
        }
    }
}

#Preview {
    RootView()
}
