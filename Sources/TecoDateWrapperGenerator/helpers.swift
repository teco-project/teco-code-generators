enum DateEncoding: String {
    case date = "TCDateEncoding"
    case timestamp = "TCTimestampEncoding"
    case timestamp_iso8601 = "TCTimestampISO8601Encoding"
}

extension DateEncoding {
    var dateFormatterType: String {
        self == .timestamp_iso8601 ? "ISO8601DateFormatter" : "DateFormatter"
    }

    static var all: [Self] {
        [.date, .timestamp, .timestamp_iso8601]
    }

    var valueDescription: String {
        self == .date ? "date" : "timestamp"
    }
}
