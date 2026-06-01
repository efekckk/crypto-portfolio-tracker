import Foundation

struct SetAlertActiveUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(id: UUID, isActive: Bool) throws {
        guard var alert = try alertRepository.alert(id: id) else { return }
        alert.isActive = isActive
        try alertRepository.save(alert)
    }
}
