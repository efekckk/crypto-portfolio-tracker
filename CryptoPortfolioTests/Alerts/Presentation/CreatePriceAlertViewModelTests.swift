import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreatePriceAlertViewModelTests: XCTestCase {
    private func makeVM() -> (CreatePriceAlertViewModel, MockAlertRepository) {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        let vm = CreatePriceAlertViewModel(coin: Coin(id: "btc", symbol: "btc", name: "Bitcoin"),
                                            createAlert: useCase)
        return (vm, repo)
    }

    func test_save_happyPath_persistsPriceCrossing() async {
        let (vm, repo) = makeVM()
        vm.targetPriceText = "75000"
        vm.direction = .above
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .priceCrossing(coinId: "btc", direction: .above, targetPrice: 75000))
    }

    func test_save_commaDecimal_normalisedToDot() async {
        let (vm, repo) = makeVM()
        vm.targetPriceText = "0,5"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        if case .priceCrossing(_, _, let target) = try? repo.alerts().first?.condition {
            XCTAssertEqual(target, 0.5, accuracy: 0.0001)
        } else {
            XCTFail("expected priceCrossing")
        }
    }

    func test_save_nonNumericInput_setsLocalizedError_returnsFalse() async {
        let (vm, _) = makeVM()
        vm.targetPriceText = "abc"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_zeroTarget_setsInvalidPriceError() async {
        let (vm, _) = makeVM()
        vm.targetPriceText = "0"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_appliesCooldownRecurrence() async {
        let (vm, repo) = makeVM()
        vm.targetPriceText = "100"
        vm.recurrence.kind = .cooldown
        vm.recurrence.cooldownSeconds = 21600
        _ = await vm.save()
        XCTAssertEqual(try? repo.alerts().first?.recurrence, .cooldown(seconds: 21600))
    }
}
