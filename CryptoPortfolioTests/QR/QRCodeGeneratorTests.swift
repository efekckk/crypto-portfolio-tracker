import XCTest
@testable import CryptoPortfolio

final class QRCodeGeneratorTests: XCTestCase {
    func test_generate_returnsImageForNonEmptyString() {
        let image = QRCodeGenerator.generate(text: "cptp://v1?coin=bitcoin&amount=0.5")
        XCTAssertNotNil(image)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
        XCTAssertGreaterThan(image?.size.height ?? 0, 0)
    }

    func test_generate_respectsRequestedSize() {
        let image = QRCodeGenerator.generate(text: "hello", size: 200)
        // CoreImage produces an upscaled bitmap; we asked for ~200pt — allow loose match.
        XCTAssertGreaterThan(image?.size.width ?? 0, 100)
    }
}
