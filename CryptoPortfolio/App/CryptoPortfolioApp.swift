import SwiftUI
import BackgroundTasks

@main
struct CryptoPortfolioApp: App {
    @State private var container = AppContainer(notifications: UserNotificationsService())

    private static let bgTaskIdentifier = "com.foneria.cryptoportfolio.alerts.refresh"

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil) { task in
            Self.handle(task: task as! BGAppRefreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appContainer, container)
                .onAppear { Self.scheduleNextBGRefresh() }
        }
    }

    // MARK: - Background refresh

    private static func scheduleNextBGRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private static func handle(task: BGAppRefreshTask) {
        scheduleNextBGRefresh()
        let container = AppContainer(notifications: UserNotificationsService())
        let workItem = Task {
            _ = await container.evaluateAndNotify(currency: .default)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { workItem.cancel() }
    }
}
