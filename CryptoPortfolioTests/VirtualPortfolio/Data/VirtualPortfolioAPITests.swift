import XCTest
@testable import CryptoPortfolio

@MainActor
final class VirtualPortfolioAPITests: XCTestCase {

    // MARK: - URLProtocol mock

    /// Drop-in URLProtocol mock that hands the test's `handler` every request
    /// the client makes. Tests inspect the captured URLRequest and emit any
    /// (Data, HTTPURLResponse) pair they like.
    final class StubURLProtocol: URLProtocol {
        nonisolated(unsafe) static var handler: ((URLRequest) -> (Data, HTTPURLResponse))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard let handler = Self.handler else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }
            let (data, response) = handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private let deviceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let baseURL = URL(string: "https://api.example.test")!

    private func makeAPI(_ handler: @escaping (URLRequest) -> (Data, HTTPURLResponse)) -> URLSessionVirtualPortfolioAPI {
        StubURLProtocol.handler = handler
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: cfg)
        return URLSessionVirtualPortfolioAPI(baseURL: baseURL, session: session,
                                              deviceIDProvider: { self.deviceID })
    }

    private func response(_ code: Int, body: String) -> (Data, HTTPURLResponse) {
        let resp = HTTPURLResponse(url: baseURL, statusCode: code,
                                   httpVersion: "HTTP/1.1", headerFields: nil)!
        return (Data(body.utf8), resp)
    }

    // MARK: - List

    func test_listPortfolios_sendsGETWithDeviceIDHeader() async throws {
        var captured: URLRequest?
        let api = makeAPI { req in
            captured = req
            return self.response(200, body: """
            {"portfolios": []}
            """)
        }
        _ = try await api.listPortfolios()
        XCTAssertEqual(captured?.httpMethod, "GET")
        XCTAssertEqual(captured?.url?.path, "/v1/virtual/portfolios")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Device-Id"), deviceID.uuidString)
    }

    func test_listPortfolios_decodesEmptyArray() async throws {
        let api = makeAPI { _ in
            self.response(200, body: """
            {"portfolios": []}
            """)
        }
        let list = try await api.listPortfolios()
        XCTAssertEqual(list.count, 0)
    }

    func test_listPortfolios_decodesSummaries() async throws {
        let api = makeAPI { _ in
            self.response(200, body: """
            {"portfolios": [
              { "id":"00000000-0000-0000-0000-000000000010","name":"Aggressive",
                "starting_balance":10000, "cash_balance":5000, "total_value":12000,
                "total_pnl":2000, "total_pnl_percent":20, "trade_count":3,
                "created_at":"2026-06-09T10:00:00Z","updated_at":"2026-06-09T11:00:00Z" }
            ]}
            """)
        }
        let list = try await api.listPortfolios()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].name, "Aggressive")
        XCTAssertEqual(list[0].tradeCount, 3)
    }

    // MARK: - Get

    func test_getPortfolio_returnsDetail() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        var captured: URLRequest?
        let api = makeAPI { req in
            captured = req
            return self.response(200, body: """
            { "id":"\(pid.uuidString)","name":"P","starting_balance":1000,
              "cash_balance":500,"total_value":1500,
              "realized_pnl":0,"unrealized_pnl":500,"total_pnl_percent":50,
              "holdings":[],
              "created_at":"2026-06-09T10:00:00Z","updated_at":"2026-06-09T10:00:00Z" }
            """)
        }
        let p = try await api.getPortfolio(id: pid)
        XCTAssertEqual(p.id, pid)
        XCTAssertEqual(p.totalPnLPercent, 50)
        XCTAssertEqual(captured?.url?.path, "/v1/virtual/portfolios/\(pid.uuidString)")
    }

    // MARK: - Create

    func test_createPortfolio_sendsPOSTBodyAndReturnsSummary() async throws {
        var captured: URLRequest?
        let api = makeAPI { req in
            captured = req
            return self.response(201, body: """
            { "id":"00000000-0000-0000-0000-000000000030","name":"New",
              "starting_balance":5000,"created_at":"2026-06-09T12:00:00Z" }
            """)
        }
        let summary = try await api.createPortfolio(name: "New", startingBalance: 5000)
        XCTAssertEqual(summary.name, "New")
        XCTAssertEqual(summary.startingBalance, 5000)
        XCTAssertEqual(summary.cashBalance, 5000) // computed
        XCTAssertEqual(summary.totalValue, 5000)
        XCTAssertEqual(summary.tradeCount, 0)
        XCTAssertEqual(captured?.httpMethod, "POST")
        // Verify body shape uses snake_case.
        let bodyData = captured?.httpBodyStream?.readAll() ?? captured?.httpBody ?? Data()
        let bodyString = String(decoding: bodyData, as: UTF8.self)
        XCTAssertTrue(bodyString.contains("\"starting_balance\""))
    }

    // MARK: - Delete

    func test_deletePortfolio_sendsDELETE() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000040")!
        var captured: URLRequest?
        let api = makeAPI { req in
            captured = req
            return (Data(), HTTPURLResponse(url: self.baseURL, statusCode: 204,
                                            httpVersion: "HTTP/1.1", headerFields: nil)!)
        }
        try await api.deletePortfolio(id: pid)
        XCTAssertEqual(captured?.httpMethod, "DELETE")
        XCTAssertEqual(captured?.url?.path, "/v1/virtual/portfolios/\(pid.uuidString)")
    }

    // MARK: - Quote

    func test_quote_sendsCoinIDQueryAndReturnsQuote() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000050")!
        var captured: URLRequest?
        let api = makeAPI { req in
            captured = req
            return self.response(200, body: """
            { "coin_id":"bitcoin","coin_name":"Bitcoin","price":80000,
              "fetched_at":"2026-06-09T13:00:00Z",
              "max_buy_amount":0.125,"max_sell_amount":0 }
            """)
        }
        let q = try await api.quote(portfolioID: pid, coinID: "bitcoin")
        XCTAssertEqual(q.coinName, "Bitcoin")
        XCTAssertEqual(q.price, 80000)
        XCTAssertEqual(captured?.url?.query, "coin_id=bitcoin")
    }

    // MARK: - Execute trade

    func test_executeTrade_sendsBodyAndReturnsPostTradeDetail() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000060")!
        var captured: URLRequest?
        let api = makeAPI { req in
            captured = req
            return self.response(201, body: """
            { "trade": { "id":1,"side":"buy","coin_id":"bitcoin",
                        "amount":0.05,"price":80000,
                        "executed_at":"2026-06-09T13:00:00Z" },
              "portfolio": { "id":"\(pid.uuidString)","name":"P",
                            "starting_balance":10000,"cash_balance":6000,
                            "total_value":10000,"realized_pnl":0,
                            "unrealized_pnl":0,"total_pnl_percent":0,
                            "holdings":[],
                            "created_at":"2026-06-09T10:00:00Z",
                            "updated_at":"2026-06-09T13:00:00Z" } }
            """)
        }
        let post = try await api.executeTrade(portfolioID: pid, side: .buy,
                                              coinID: "bitcoin", amount: 0.05)
        XCTAssertEqual(post.cashBalance, 6000)
        XCTAssertEqual(captured?.httpMethod, "POST")
    }

    // MARK: - History

    func test_tradeHistory_passesLimitAndCursorInQuery() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000070")!
        var captured: URLRequest?
        let api = makeAPI { req in
            captured = req
            return self.response(200, body: """
            { "trades":[],"next_cursor": null }
            """)
        }
        _ = try await api.tradeHistory(portfolioID: pid, beforeID: 12345, limit: 25)
        let query = captured?.url?.query ?? ""
        XCTAssertTrue(query.contains("limit=25"))
        XCTAssertTrue(query.contains("before_id=12345"))
    }

    // MARK: - Error mapping

    func test_409_mapsToConflict() async throws {
        let api = makeAPI { _ in
            self.response(409, body: """
            {"error":"conflict","detail":"name already taken"}
            """)
        }
        do {
            _ = try await api.createPortfolio(name: "Dup", startingBalance: 100)
            XCTFail("should throw")
        } catch let VirtualAPIError.conflict(detail) {
            XCTAssertEqual(detail, "name already taken")
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_422_unprocessable_carriesDetailString() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000080")!
        let api = makeAPI { _ in
            self.response(422, body: """
            {"error":"unprocessable","detail":"insufficient_cash"}
            """)
        }
        do {
            _ = try await api.executeTrade(portfolioID: pid, side: .buy,
                                            coinID: "bitcoin", amount: 999)
            XCTFail("should throw")
        } catch let VirtualAPIError.unprocessable(detail) {
            XCTAssertEqual(detail, "insufficient_cash")
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_403_mapsToForbidden() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000081")!
        let api = makeAPI { _ in
            self.response(403, body: """
            {"error":"forbidden","detail":"not your portfolio"}
            """)
        }
        do {
            _ = try await api.getPortfolio(id: pid)
            XCTFail("should throw")
        } catch VirtualAPIError.forbidden {
            // ok
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_404_mapsToNotFound() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000082")!
        let api = makeAPI { _ in self.response(404, body: "{}") }
        do {
            _ = try await api.getPortfolio(id: pid)
            XCTFail("should throw")
        } catch VirtualAPIError.notFound {
            // ok
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_429_mapsToRateLimited() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000083")!
        let api = makeAPI { _ in self.response(429, body: """
        {"error":"rate_limited","detail":"too many"}
        """) }
        do {
            _ = try await api.executeTrade(portfolioID: pid, side: .buy,
                                            coinID: "bitcoin", amount: 1)
            XCTFail("should throw")
        } catch VirtualAPIError.rateLimited {
            // ok
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_502_mapsToUpstream() async throws {
        let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000084")!
        let api = makeAPI { _ in self.response(502, body: """
        {"error":"upstream_error","detail":"down"}
        """) }
        do {
            _ = try await api.quote(portfolioID: pid, coinID: "bitcoin")
            XCTFail("should throw")
        } catch VirtualAPIError.upstream {
            // ok
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}

// Helper to read URLRequest's bodyStream (URLSession's data(for:) sometimes
// repackages bodies into a stream).
private extension InputStream {
    func readAll() -> Data {
        open(); defer { close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        while hasBytesAvailable {
            let n = read(buffer, maxLength: 4096)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}
