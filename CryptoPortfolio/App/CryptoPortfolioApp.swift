import SwiftUI

@main
struct CryptoPortfolioApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appContainer, container)
        }
    }
}
