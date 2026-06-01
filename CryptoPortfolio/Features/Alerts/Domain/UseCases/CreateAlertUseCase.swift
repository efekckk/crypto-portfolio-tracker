import Foundation

struct CreateAlertUseCase {
    let alertRepository: AlertRepository

    func callAsFunction(coinId: String, targetPrice: Double, direction: PriceAlert.Direction) throws {
        guard targetPrice > 0 else { throw AlertError.invalidPrice }
        let alert = PriceAlert(coinId: coinId, targetPrice: targetPrice, direction: direction)
        try alertRepository.save(alert)
    }
}
