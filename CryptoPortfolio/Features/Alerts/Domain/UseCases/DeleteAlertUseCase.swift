import Foundation

struct DeleteAlertUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(id: UUID) throws {
        try alertRepository.delete(id: id)
    }
}
