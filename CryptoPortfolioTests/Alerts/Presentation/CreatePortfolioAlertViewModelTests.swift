import XCTest
@testable import CryptoPortfolio

@MainActor
final class CreatePortfolioAlertViewModelTests: XCTestCase {
    private func makeVM(metric: CreatePortfolioAlertViewModel.Metric) -> (CreatePortfolioAlertViewModel, MockAlertRepository) {
        let repo = MockAlertRepository()
        let useCase = CreateAlertUseCase(alertRepository: repo)
        let vm = CreatePortfolioAlertViewModel(metric: metric, createAlert: useCase)
        return (vm, repo)
    }

    func test_value_above_happyPath() async {
        let (vm, repo) = makeVM(metric: CreatePortfolioAlertViewModel.Metric.value)
        vm.direction = AlertCondition.Direction.above
        vm.thresholdText = "100000"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .portfolioValue(direction: .above, threshold: 100_000))
    }

    func test_value_rejectsNonPositiveTarget() async {
        let (vm, _) = makeVM(metric: CreatePortfolioAlertViewModel.Metric.value)
        vm.thresholdText = "0"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }

    func test_pnlPercent_below_happyPath_negative() async {
        let (vm, repo) = makeVM(metric: CreatePortfolioAlertViewModel.Metric.pnlPercent)
        vm.direction = AlertCondition.Direction.below
        vm.thresholdText = "-10"
        let saved = await vm.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(try? repo.alerts().first?.condition,
                       .portfolioPnLPercent(direction: .below, threshold: -10))
    }

    func test_pnlPercent_rejectsZeroThreshold() async {
        let (vm, _) = makeVM(metric: CreatePortfolioAlertViewModel.Metric.pnlPercent)
        vm.thresholdText = "0"
        let saved = await vm.save()
        XCTAssertFalse(saved)
        XCTAssertNotNil(vm.saveError)
    }
}
