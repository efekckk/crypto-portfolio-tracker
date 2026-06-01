import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreateAlertViewModelTests: XCTestCase {

    private func makeSUT(searchResult: [Coin] = [], searchError: Error? = nil)
        -> (CreateAlertViewModel, MockCoinRepository, MockAlertRepository) {
        let coinRepo = MockCoinRepository()
        coinRepo.searchResult = searchResult
        coinRepo.errorToThrow = searchError
        let alertRepo = MockAlertRepository()
        let vm = CreateAlertViewModel(
            searchCoins: SearchCoinsUseCase(coinRepository: coinRepo),
            createAlert: CreateAlertUseCase(alertRepository: alertRepo)
        )
        return (vm, coinRepo, alertRepo)
    }

    func test_initialResults_areEmpty() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.results, .empty)
    }

    func test_search_setsLoadedWithHits() async {
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")
        let (sut, _, _) = makeSUT(searchResult: [coin])
        sut.query = "bit"
        await sut.search()
        XCTAssertEqual(sut.results, .loaded([coin]))
    }

    func test_save_validAlert_returnsTrue_andPersists() async {
        let (sut, _, alertRepo) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .above, targetPriceText: "50000")

        XCTAssertTrue(saved)
        XCTAssertEqual(try alertRepo.alerts().count, 1)
        XCTAssertEqual(try alertRepo.alerts().first?.targetPrice, 50_000)
    }

    func test_save_normalisesCommaDecimal() async {
        let (sut, _, alertRepo) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .below, targetPriceText: "49999,50")

        XCTAssertTrue(saved)
        XCTAssertEqual(try alertRepo.alerts().first?.targetPrice, 49_999.5)
    }

    func test_save_invalidPrice_returnsFalse_andSetsError() async {
        let (sut, _, _) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .above, targetPriceText: "0")

        XCTAssertFalse(saved)
        XCTAssertNotNil(sut.saveError)
    }

    func test_save_unparseablePrice_returnsFalse() async {
        let (sut, _, _) = makeSUT()
        let coin = Coin(id: "bitcoin", symbol: "btc", name: "Bitcoin")

        let saved = await sut.save(coin: coin, direction: .above, targetPriceText: "abc")

        XCTAssertFalse(saved)
        XCTAssertNotNil(sut.saveError)
    }
}
