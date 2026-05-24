import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            PlaceholderTab(titleKey: "tab.portfolio", systemImage: "chart.pie.fill")
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
