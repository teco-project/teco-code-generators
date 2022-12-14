protocol DateEncodingProtocol: Equatable {
    static var date: Self { get }
    static var timestamp: Self { get }
    static var timestamp_iso8601: Self { get }
    
    var optional: Bool { get }

    var propertyWrapperType: String { get }
}

enum DateEncoding: DateEncodingProtocol {
    case date
    case timestamp
    case timestamp_iso8601
    
    var optional: Bool { false }

    var propertyWrapperType: String {
        switch self {
        case .date:
            return "TCDateEncoding"
        case .timestamp:
            return "TCTimestampEncoding"
        case .timestamp_iso8601:
            return "TCTimestampISO8601Encoding"
        }
    }
}

enum OptionalDateEncoding: DateEncodingProtocol {
    case date
    case timestamp
    case timestamp_iso8601
    
    var optional: Bool { true }

    var propertyWrapperType: String {
        switch self {
        case .date:
            return "TCDateEncodingOptional"
        case .timestamp:
            return "TCTimestampEncodingOptional"
        case .timestamp_iso8601:
            return "TCTimestampISO8601EncodingOptional"
        }
    }
}

extension DateEncodingProtocol {
    var dateFormatterType: String {
        self == .timestamp_iso8601 ? "ISO8601DateFormatter" : "DateFormatter"
    }
    
    static var all: [Self] {
        [.date, .timestamp, .timestamp_iso8601]
    }

    var description: String {
        self == .date ? "date" : "timestamp"
    }
    
    var optionalMark: String {
        self.optional ? "?" : ""
    }
}
