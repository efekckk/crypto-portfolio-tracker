import XCTest
@testable import CryptoPortfolio

final class APIErrorUserFacingMessageTests: XCTestCase {

    func test_rateLimited_messageContainsRateWord_inSomeLanguage() {
        let s = APIError.rateLimited.userFacingMessage
        XCTAssertFalse(s.isEmpty)
        XCTAssertNotEqual(s, "Something went wrong.")
    }

    func test_transport_includesMessageString() {
        let s = APIError.transport("offline").userFacingMessage
        XCTAssertTrue(s.contains("offline"), "Transport error must interpolate the underlying message")
    }

    func test_requestFailed_includesStatusCode() {
        let s = APIError.requestFailed(statusCode: 503).userFacingMessage
        XCTAssertTrue(s.contains("503"), "Request-failed error must include the status code")
    }

    func test_decoding_returnsNonEmpty() {
        XCTAssertFalse(APIError.decoding("any").userFacingMessage.isEmpty)
    }

    func test_invalidURL_returnsNonEmpty() {
        XCTAssertFalse(APIError.invalidURL.userFacingMessage.isEmpty)
    }

    func test_genericError_fallbackPath() {
        struct OtherError: Error {}
        let s = OtherError().userFacingMessage
        XCTAssertFalse(s.isEmpty)
    }
}
