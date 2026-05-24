import XCTest
@testable import CryptoPortfolio

private struct StubResponse: Decodable, Equatable {
    let value: String
}

final class HTTPClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    private func makeSUT(apiKey: String? = nil) -> URLSessionHTTPClient {
        URLSessionHTTPClient(
            session: MockURLProtocol.makeSession(),
            baseURL: URL(string: "https://example.com/api/v3")!,
            apiKey: apiKey
        )
    }

    func test_send_decodesSuccessfulJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, #"{"value":"ok"}"#.data(using: .utf8)!)
        }
        let sut = makeSUT()

        let result = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)

        XCTAssertEqual(result, StubResponse(value: "ok"))
    }

    func test_send_buildsURLWithPathAndQueryAndAPIKeyHeader() async throws {
        var captured: URLRequest?
        MockURLProtocol.requestHandler = { request in
            captured = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, #"{"value":"ok"}"#.data(using: .utf8)!)
        }
        let sut = makeSUT(apiKey: "demo-key")

        _ = try await sut.send(
            Endpoint(path: "coins/markets", queryItems: [URLQueryItem(name: "vs_currency", value: "usd")]),
            as: StubResponse.self
        )

        XCTAssertEqual(captured?.url?.absoluteString, "https://example.com/api/v3/coins/markets?vs_currency=usd")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "x-cg-demo-api-key"), "demo-key")
    }

    func test_send_omitsAPIKeyHeaderWhenKeyIsNil() async throws {
        var captured: URLRequest?
        MockURLProtocol.requestHandler = { request in
            captured = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"value":"ok"}"#.data(using: .utf8)!)
        }
        let sut = makeSUT(apiKey: nil)

        _ = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)

        XCTAssertNil(captured?.value(forHTTPHeaderField: "x-cg-demo-api-key"))
    }

    func test_send_throwsRateLimitedOn429() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let sut = makeSUT()

        await assertThrows(sut, expected: .rateLimited)
    }

    func test_send_throwsRequestFailedOnServerError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let sut = makeSUT()

        await assertThrows(sut, expected: .requestFailed(statusCode: 500))
    }

    func test_send_throwsDecodingOnMalformedJSON() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }
        let sut = makeSUT()

        do {
            _ = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)
            XCTFail("Expected to throw")
        } catch let error as APIError {
            if case .decoding = error { /* ok */ } else { XCTFail("Expected .decoding, got \(error)") }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: - Helpers

    private func assertThrows(_ sut: URLSessionHTTPClient, expected: APIError,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await sut.send(Endpoint(path: "ping"), as: StubResponse.self)
            XCTFail("Expected to throw", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected APIError, got \(error)", file: file, line: line)
        }
    }
}
