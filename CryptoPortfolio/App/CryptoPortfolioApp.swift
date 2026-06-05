import SwiftUI
import BackgroundTasks

@main
struct CryptoPortfolioApp: App {
    private let container = AppContainer(notifications: UserNotificationsService())

    private static let bgTaskIdentifier = "com.foneria.cryptoportfolio.alerts.refresh"

    init() {
        let container = self.container
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil) { task in
            Self.handle(task: task as! BGAppRefreshTask, container: container)
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
    private static func handle(task: BGAppRefreshTask, container: AppContainer) {
        scheduleNextBGRefresh()
        let workItem = Task {
            _ = await container.evaluateAndNotify(currency: .default)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            workItem.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
