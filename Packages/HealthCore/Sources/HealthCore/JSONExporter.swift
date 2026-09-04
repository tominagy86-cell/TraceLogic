import Foundation

public enum ExportError: Error, Equatable, Sendable {
    case encodingFailed
}

/// Bármely `Encodable` (a HealthCore modelljei mind azok) JSON exportja — determinisztikus
/// (rendezett kulcsok), ISO-8601 dátumokkal. Debug/export képernyőhöz és offline elemzéshez.
public enum JSONExporter {

    public static func data<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(value)
        } catch {
            throw ExportError.encodingFailed
        }
    }

    public static func string<T: Encodable>(_ value: T) throws -> String {
        let raw = try data(value)
        guard let string = String(data: raw, encoding: .utf8) else { throw ExportError.encodingFailed }
        return string
    }
}
