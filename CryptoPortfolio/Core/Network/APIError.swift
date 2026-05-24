import Foundation

enum APIError: Error, Equatable {
    case invalidURL
    case requestFailed(statusCode: Int)
    case rateLimited
    case decoding(String)
    case transport(String)
}
