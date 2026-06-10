import Foundation

/// HTTP-backed surface for the virtual portfolio feature. The protocol is
/// Sendable so view-models can call it across actor boundaries; the concrete
/// `URLSessionVirtualPortfolioAPI` lives in this file too.
protocol VirtualPortfolioAPI: Sendable {
    func listPortfolios() async throws -> [VirtualPortfolioSummary]
    func getPortfolio(id: UUID) async throws -> VirtualPortfolio
    func createPortfolio(name: String, startingBalance: Double) async throws -> VirtualPortfolioSummary
    func deletePortfolio(id: UUID) async throws
    func quote(portfolioID: UUID, coinID: String) async throws -> VirtualQuote
    func executeTrade(portfolioID: UUID, side: VirtualTrade.Side, coinID: String, amount: Double) async throws -> VirtualPortfolio
    func tradeHistory(portfolioID: UUID, beforeID: Int64?, limit: Int) async throws -> VirtualTradeHistoryPage
}

/// `VirtualPortfolioAPI` implementation that talks to the Go backend.
struct URLSessionVirtualPortfolioAPI: VirtualPortfolioAPI {
    let baseURL: URL
    let session: URLSession
    /// Closure so the device id (resolved from UserDefaults / device
    /// registration) can be supplied lazily — the API doesn't need a long
    /// lifecycle to it.
    let deviceIDProvider: @Sendable () -> UUID?

    init(baseURL: URL,
         session: URLSession = .shared,
         deviceIDProvider: @escaping @Sendable () -> UUID?) {
        self.baseURL = baseURL
        self.session = session
        self.deviceIDProvider = deviceIDProvider
    }

    // MARK: - Endpoints

    func listPortfolios() async throws -> [VirtualPortfolioSummary] {
        let dto: VirtualPortfoliosListResponseDTO = try await send(
            "/v1/virtual/portfolios", method: "GET"
        )
        return dto.portfolios.compactMap { $0.toDomain() }
    }

    func getPortfolio(id: UUID) async throws -> VirtualPortfolio {
        let dto: VirtualPortfolioDetailDTO = try await send(
            "/v1/virtual/portfolios/\(id.uuidString)", method: "GET"
        )
        guard let domain = dto.toDomain() else {
            throw VirtualAPIError.transport("malformed portfolio id")
        }
        return domain
    }

    func createPortfolio(name: String, startingBalance: Double) async throws -> VirtualPortfolioSummary {
        struct Body: Encodable { let name: String; let startingBalance: Double }
        let dto: VirtualPortfolioCreateResponseDTO = try await send(
            "/v1/virtual/portfolios", method: "POST",
            body: Body(name: name, startingBalance: startingBalance)
        )
        guard let uuid = UUID(uuidString: dto.id) else {
            throw VirtualAPIError.transport("malformed portfolio id from server")
        }
        // Create endpoint returns just metadata; surface a Summary with
        // computed fields filled in from the input (no trades yet).
        return VirtualPortfolioSummary(
            id: uuid, name: dto.name, startingBalance: dto.startingBalance,
            cashBalance: dto.startingBalance, totalValue: dto.startingBalance,
            totalPnL: 0, totalPnLPercent: 0, tradeCount: 0,
            createdAt: dto.createdAt, updatedAt: dto.createdAt
        )
    }

    func deletePortfolio(id: UUID) async throws {
        try await sendNoContent(
            "/v1/virtual/portfolios/\(id.uuidString)", method: "DELETE"
        )
    }

    func quote(portfolioID: UUID, coinID: String) async throws -> VirtualQuote {
        let dto: VirtualQuoteDTO = try await send(
            "/v1/virtual/portfolios/\(portfolioID.uuidString)/quote",
            method: "GET",
            queryItems: [URLQueryItem(name: "coin_id", value: coinID)]
        )
        return dto.toDomain()
    }

    func executeTrade(portfolioID: UUID, side: VirtualTrade.Side, coinID: String, amount: Double) async throws -> VirtualPortfolio {
        struct Body: Encodable { let side: String; let coinId: String; let amount: Double }
        let dto: ExecuteTradeResponseDTO = try await send(
            "/v1/virtual/portfolios/\(portfolioID.uuidString)/trades",
            method: "POST",
            body: Body(side: side.rawValue, coinId: coinID, amount: amount)
        )
        guard let domain = dto.portfolio.toDomain() else {
            throw VirtualAPIError.transport("malformed post-trade portfolio")
        }
        return domain
    }

    func tradeHistory(portfolioID: UUID, beforeID: Int64?, limit: Int) async throws -> VirtualTradeHistoryPage {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let beforeID {
            items.append(URLQueryItem(name: "before_id", value: String(beforeID)))
        }
        let dto: VirtualTradeHistoryPageDTO = try await send(
            "/v1/virtual/portfolios/\(portfolioID.uuidString)/trades",
            method: "GET", queryItems: items
        )
        return dto.toDomain()
    }

    // MARK: - HTTP dispatcher

    /// Sends a request with a JSON body (or no body if `body` is nil) and
    /// decodes the response into `T`. Maps backend error envelopes to
    /// `VirtualAPIError`.
    private func send<T: Decodable>(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) async throws -> T {
        let (data, response) = try await execute(path: path, method: method,
                                                  queryItems: queryItems, body: body)
        try mapStatus(response, data: data)
        do {
            return try VirtualJSONCoder.decoder().decode(T.self, from: data)
        } catch {
            throw VirtualAPIError.transport("decode \(T.self): \(error.localizedDescription)")
        }
    }

    /// Variant for 204 No Content endpoints.
    private func sendNoContent(_ path: String, method: String) async throws {
        let (data, response) = try await execute(path: path, method: method,
                                                  queryItems: nil, body: nil)
        try mapStatus(response, data: data)
    }

    private func execute(
        path: String,
        method: String,
        queryItems: [URLQueryItem]?,
        body: Encodable?
    ) async throws -> (Data, URLResponse) {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                             resolvingAgainstBaseURL: false) else {
            throw VirtualAPIError.transport("could not build URL")
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw VirtualAPIError.transport("could not assemble URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let deviceID = deviceIDProvider() {
            req.setValue(deviceID.uuidString, forHTTPHeaderField: "X-Device-Id")
        }
        if let body {
            do {
                req.httpBody = try VirtualJSONCoder.encoder().encode(AnyEncodable(body))
            } catch {
                throw VirtualAPIError.transport("encode body: \(error.localizedDescription)")
            }
        }

        do {
            return try await session.data(for: req)
        } catch {
            throw VirtualAPIError.transport(error.localizedDescription)
        }
    }

    /// Converts a non-2xx response into a typed `VirtualAPIError`.
    private func mapStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw VirtualAPIError.transport("non-HTTP response")
        }
        let code = http.statusCode
        if (200...299).contains(code) { return }

        // Best-effort decode of the envelope.
        struct Envelope: Decodable { let error: String?; let detail: String? }
        let envelope = (try? JSONDecoder().decode(Envelope.self, from: data)) ?? Envelope(error: nil, detail: nil)
        let detail = envelope.detail ?? envelope.error ?? "request failed"

        switch code {
        case 400: throw VirtualAPIError.invalidPayload(detail)
        case 401: throw VirtualAPIError.deviceUnknown(detail)
        case 403: throw VirtualAPIError.forbidden(detail)
        case 404: throw VirtualAPIError.notFound(detail)
        case 409: throw VirtualAPIError.conflict(detail)
        case 422: throw VirtualAPIError.unprocessable(detail)
        case 429: throw VirtualAPIError.rateLimited(detail)
        case 502: throw VirtualAPIError.upstream(detail)
        case 500...599: throw VirtualAPIError.server(detail)
        default: throw VirtualAPIError.unknown(code, detail)
        }
    }
}

/// Type-erased Encodable so a `private` Body struct can be passed through
/// the generic dispatcher without exposing its concrete type.
private struct AnyEncodable: Encodable {
    let inner: Encodable
    init(_ inner: Encodable) { self.inner = inner }
    func encode(to encoder: Encoder) throws {
        try inner.encode(to: encoder)
    }
}
