import Foundation

struct GetAlertsUseCase {
    let alertRepository: AlertRepository

    func callAsFunction() throws -> [PriceAlert] {
        try alertRepository.alerts()
    }
}
