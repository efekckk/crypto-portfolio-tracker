import Foundation

/// Typed errors a `VirtualPortfolioAPI` call can produce. Construction
/// happens in `URLSessionVirtualPortfolioAPI` after parsing the backend's
/// `{ "error": <code>, "detail": <message> }` envelope.
enum VirtualAPIError: Error, Equatable {
    /// 400 — body validation failed or input was malformed.
    case invalidPayload(String)
    /// 401 — X-Device-Id missing / unknown.
    case deviceUnknown(String)
    /// 403 — portfolio belongs to a different device.
    case forbidden(String)
    /// 404 — resource not found.
    case notFound(String)
    /// 409 — portfolio name taken or limit reached.
    case conflict(String)
    /// 422 — semantically invalid (insufficient cash/holdings, unknown coin).
    /// `detail` carries the machine-readable code the UI maps to a localized message.
    case unprocessable(String)
    /// 429 — too many trade requests for this device.
    case rateLimited(String)
    /// 502 — upstream pricing service unavailable.
    case upstream(String)
    /// 5xx other / opaque.
    case server(String)
    /// Transport / parsing failures.
    case transport(String)
    /// Backend returned a status code we don't know how to handle.
    case unknown(Int, String)
}
