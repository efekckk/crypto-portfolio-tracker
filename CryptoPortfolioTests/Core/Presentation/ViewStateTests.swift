import XCTest
@testable import CryptoPortfolio

final class ViewStateTests: XCTestCase {
    func test_equatableForSimpleCases() {
        let a: ViewState<String> = .loading
        let b: ViewState<String> = .loading
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, ViewState<String>.empty)
    }

    func test_equatableForLoadedAndError() {
        XCTAssertEqual(ViewState<String>.loaded("x"), ViewState<String>.loaded("x"))
        XCTAssertNotEqual(ViewState<String>.loaded("x"), ViewState<String>.loaded("y"))
        XCTAssertEqual(ViewState<String>.error("oops"), ViewState<String>.error("oops"))
    }
}
