import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreateAlertViewModelTests: XCTestCase {

    private func makeSUT(searchResult: [Coin] = [], searchError: Error? = nil)
        -> (CreateAlertViewModel, MockCoinRepository) {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = searchResult
        coinRepo.errorToThrow = searchError
        let vm = CreateAlertViewModel(
            searchCoins: SearchCoinsUseCase(coinRepository: coinRepo)
        )
        return (vm, coinRepo)
    }

    func test_initialResults_areEmpty() {
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.results, .empty)
    }

    func test_search_setsLoadedWithHits() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")
        let (sut, _) = makeSUT(searchResult: [coin])
        sut.query = "bit"
        await sut.search()
        XCTAssertEqual(sut.results, .loaded([coin]))
    }
}
