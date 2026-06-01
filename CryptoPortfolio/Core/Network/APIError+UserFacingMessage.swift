import Foundation

extension APIError {
    /// English fallback messages used when no localized error is in play.
    /// Phase 7 will replace these with `LocalizedStringKey`-backed strings.
    var userFacingMessage: String {
        switch self {
        case .rateLimited:                  return "Rate limited. Please try again in a moment."
        case .transport(let msg):           return "Network error: \(msg)"
        case .requestFailed(let code):      return "Server error (\(code))."
        case .decoding:                     return "Could not parse server response."
        case .invalidURL:                   return "Invalid request."
        }
    }
}

extension Error {
    /// Convenience: `APIError` instances get their tailored message; everything else
    /// falls back to a generic string. Keeps view-model error paths to a single line.
    var userFacingMessage: String {
        (self as? APIError)?.userFacingMessage ?? "Something went wrong."
    }
}
