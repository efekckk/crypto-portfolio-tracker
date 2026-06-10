import Foundation

/// JSONEncoder + JSONDecoder preset for the virtual portfolio wire format:
/// snake_case keys + RFC3339 dates. Reused by every request/response.
enum VirtualJSONCoder {
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return d
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601WithFractionalSeconds
        return e
    }
}

private extension JSONDecoder.DateDecodingStrategy {
    /// RFC3339 with optional fractional seconds (`2026-06-06T10:00:00Z` or
    /// `2026-06-06T10:00:00.123Z`). Apple's built-in `.iso8601` rejects the
    /// fractional form; we accept both.
    static var iso8601WithFractionalSeconds: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = withFraction.date(from: raw) { return d }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let d = plain.date(from: raw) { return d }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Date \"\(raw)\" not RFC3339 / ISO8601.")
        }
    }
}

private extension JSONEncoder.DateEncodingStrategy {
    static var iso8601WithFractionalSeconds: JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            var container = encoder.singleValueContainer()
            try container.encode(f.string(from: date))
        }
    }
}
