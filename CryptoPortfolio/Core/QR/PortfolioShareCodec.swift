import Foundation

enum PortfolioShareCodecError: Error, Equatable {
    case malformedURL
    case invalidScheme
    case invalidVersion
    case missingCoin
    case missingOrInvalidAmount
}

/// Encodes/decodes `cptp://v1?coin=<id>&amount=<decimal>` URLs.
enum PortfolioShareCodec {
    static let scheme = "cptp"
    static let version = "v1"

    static func encode(_ code: PortfolioShareCode) -> String {
        var components = URLComponents()
        components.scheme = scheme
        components.host = version
        components.queryItems = [
            URLQueryItem(name: "coin", value: code.coinId),
            URLQueryItem(name: "amount", value: String(code.amount))
        ]
        return components.url?.absoluteString
            ?? "\(scheme)://\(version)?coin=\(code.coinId)&amount=\(code.amount)"
    }

    static func decode(_ raw: String) throws -> PortfolioShareCode {
        guard let components = URLComponents(string: raw) else {
            throw PortfolioShareCodecError.malformedURL
        }
        guard components.scheme == scheme else { throw PortfolioShareCodecError.invalidScheme }
        guard components.host == version else { throw PortfolioShareCodecError.invalidVersion }

        let items = (components.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value ?? ""
        }
        guard let coin = items["coin"], !coin.isEmpty else { throw PortfolioShareCodecError.missingCoin }
        guard let amountStr = items["amount"], let amount = Double(amountStr), amount > 0 else {
            throw PortfolioShareCodecError.missingOrInvalidAmount
        }
        return PortfolioShareCode(coinId: coin, amount: amount)
    }
}
