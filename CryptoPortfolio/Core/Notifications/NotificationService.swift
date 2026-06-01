import Foundation

/// Local notifications abstraction. Production uses `UserNotificationsService`;
/// tests inject `NoOpNotificationService` or a spy.
protocol NotificationService {
    func requestAuthorizationIfNeeded() async -> Bool
    func fire(title: String, body: String, identifier: String) async
}

struct NoOpNotificationService: NotificationService {
    func requestAuthorizationIfNeeded() async -> Bool { false }
    func fire(title: String, body: String, identifier: String) async {}
}
