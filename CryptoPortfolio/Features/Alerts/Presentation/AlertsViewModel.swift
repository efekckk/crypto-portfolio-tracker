import Foundation

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[PriceAlert]> = .loading

    private let getAlerts: GetAlertsUseCase
    private let deleteAlertUseCase: DeleteAlertUseCase
    private let setActiveUseCase: SetAlertActiveUseCase
    private let evaluate: EvaluateAlertsUseCase
    private let notifications: NotificationService
    private let currency: Currency

    init(getAlerts: GetAlertsUseCase,
         deleteAlert: DeleteAlertUseCase,
         setActive: SetAlertActiveUseCase,
         evaluate: EvaluateAlertsUseCase,
         notifications: NotificationService,
         currency: Currency = .default) {
        self.getAlerts = getAlerts
        self.deleteAlertUseCase = deleteAlert
        self.setActiveUseCase = setActive
        self.evaluate = evaluate
        self.notifications = notifications
        self.currency = currency
    }

    func load() async {
        state = .loading
        do {
            let alerts = try getAlerts()
            state = alerts.isEmpty ? .empty : .loaded(alerts)
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func delete(id: UUID) async {
        do {
            try deleteAlertUseCase(id: id)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func setActive(id: UUID, isActive: Bool) async {
        do {
            try setActiveUseCase(id: id, isActive: isActive)
            await load()
        } catch {
            state = .error(error.userFacingMessage)
        }
    }

    func evaluateNow() async {
        do {
            let firings = try await evaluate(now: Date())
            for firing in firings {
                let title = AlertNotificationFormatter.title(for: firing)
                let body = AlertNotificationFormatter.body(for: firing,
                                                           coinName: nil,
                                                           currency: currency)
                await notifications.fire(title: title, body: body,
                                         identifier: firing.alert.id.uuidString)
            }
            if !firings.isEmpty { await load() }
        } catch {
            // Evaluation errors are non-fatal for v1; preserve current state.
        }
    }

    func requestNotificationPermission() async {
        _ = await notifications.requestAuthorizationIfNeeded()
    }
}
