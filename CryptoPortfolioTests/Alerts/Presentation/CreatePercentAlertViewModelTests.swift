import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreatePercentAlertViewModelTests: XCTestCase {
    private func makeVM() -> (CreatePercentAlertViewModel, MockAlertRepository) {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        let vm = CreatePercentAlertViewModel(coin: Coin(id: "btc", symbol: "btc", name: "Bitcoin"),
                                              createAlert: useCase)
        return (vm, repo)
    }

    func test_save_happyPath_24h_above() async {
        let (vm, repo) = makeVM()
        vm.window = .h24
        vm.direction = .above
        vm.thresholdText = "5"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .percentChange(coinId: "btc", direction: .above, window: .h24, threshold: 5))
    }

    func test_save_negativeThreshold_7d_below() async {
        let (vm, repo) = makeVM()
        vm.window = .d7
        vm.direction = .below
        vm.thresholdText = "-5"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .percentChange(coinId: "btc", direction: .below, window: .d7, threshold: -5))
    }

    func test_save_zeroThreshold_setsInvalidThresholdError() async {
        let (vm, _) = makeVM()
        vm.thresholdText = "0"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_nonNumeric_setsLocalizedError() async {
        let (vm, _) = makeVM()
        vm.thresholdText = "abc"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }
}
