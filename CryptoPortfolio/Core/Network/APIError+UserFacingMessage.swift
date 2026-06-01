import Foundation

extension APIError {
    /// Localized user-facing message for this error. Falls back to the English text
    /// embedded as the localised key's default value if no string catalog entry is
    /// found.
    var userFacingMessage: String {
        switch self {
        case .rateLimited:
            return String(localized: "error.api.rateLimited",
                          defaultValue: "Rate limited. Please try again in a moment.")
        case .transport(let msg):
            let format = String(localized: "error.api.networkFormat",
                                defaultValue: "Network error: %@")
            return String(format: format, msg)
        case .requestFailed(let code):
            let format = String(localized: "error.api.serverErrorFormat",
                                defaultValue: "Server error (%d).")
            return String(format: format, code)
        case .decoding:
            return String(localized: "error.api.decoding",
                          defaultValue: "Could not parse server response.")
        case .invalidURL:
            return String(localized: "error.api.invalidURL",
                          defaultValue: "Invalid request.")
        }
    }
}

extension Error {
    var userFacingMessage: String {
        (self as? APIError)?.userFacingMessage
            ?? String(localized: "error.generic", defaultValue: "Something went wrong.")
    }
}
