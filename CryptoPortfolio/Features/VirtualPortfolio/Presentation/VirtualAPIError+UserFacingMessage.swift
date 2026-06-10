import Foundation

extension VirtualAPIError {
    /// Localized one-line message suitable for inline error banners. The
    /// raw L10n keys land in Localizable.xcstrings later; defaults make the
    /// strings legible immediately.
    var userFacingMessage: String {
        switch self {
        case .invalidPayload(let detail):
            if detail.isEmpty {
                return String(localized: "virtual.error.invalid_payload",
                              defaultValue: "Request was invalid.")
            } else {
                return detail
            }
        case .deviceUnknown:
            return String(localized: "virtual.error.device_unknown",
                          defaultValue: "Device isn't registered.")
        case .forbidden:
            return String(localized: "virtual.error.forbidden",
                          defaultValue: "You can't access this portfolio.")
        case .notFound:
            return String(localized: "virtual.error.not_found",
                          defaultValue: "Portfolio not found.")
        case .conflict(let detail):
            if detail.isEmpty {
                return String(localized: "virtual.error.conflict",
                              defaultValue: "That portfolio already exists.")
            } else {
                return detail
            }
        case .unprocessable(let detail):
            switch detail {
            case "insufficient_cash":
                return String(localized: "virtual.error.insufficient_cash",
                              defaultValue: "Not enough cash.")
            case "insufficient_holdings":
                return String(localized: "virtual.error.insufficient_holdings",
                              defaultValue: "Not enough holdings.")
            default:
                if detail.isEmpty {
                    return String(localized: "virtual.error.unprocessable",
                                  defaultValue: "Request couldn't be processed.")
                } else {
                    return detail
                }
            }
        case .rateLimited:
            return String(localized: "virtual.error.rate_limited",
                          defaultValue: "Slow down — too many trades.")
        case .upstream:
            return String(localized: "virtual.error.upstream",
                          defaultValue: "Couldn't fetch current price.")
        case .server, .unknown, .transport:
            return String(localized: "virtual.error.generic",
                          defaultValue: "Something went wrong.")
        }
    }
}
