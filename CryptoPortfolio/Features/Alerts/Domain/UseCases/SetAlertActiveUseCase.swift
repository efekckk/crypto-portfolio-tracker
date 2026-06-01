import Foundation

struct SetAlertActiveUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(id: UUID, isActive: Bool) throws {
        guard var alert = try alertRepository.alert(id: id) else { return }
        alert.isActive = isActive
        // Re-arming a previously fired alert clears the fired timestamp so
        // EvaluateAlertsUseCase will consider it again.
        if isActive { alert.firedAt = nil }
        try alertRepository.save(alert)
    }
}
