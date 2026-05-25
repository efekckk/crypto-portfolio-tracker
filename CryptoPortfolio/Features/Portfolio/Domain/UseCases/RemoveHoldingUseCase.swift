import Foundation

struct RemoveHoldingUseCase {
    let portfolioRepository: PortfolioRepository

    func callAsFunction(coinId: String) throws {
        try portfolioRepository.remove(coinId: coinId)
    }
}
