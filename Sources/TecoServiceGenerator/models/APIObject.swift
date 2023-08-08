struct APIObject: Codable {
    private let _document: String
    let members: [Member]
    private let _type: `Type`?
    var usage: Usage?

    var document: String { self._document == "无" ? "" : self._document }
    var type: `Type` { self._type ?? .object }
    var initializable: Bool { self.usage == .in || self.usage == .both }

    enum CodingKeys: String, CodingKey {
        case _document = "document"
        case members
        case _type = "type"
        case usage
    }

    enum Usage: String, Codable {
        case `in`
        case out
        case both
    }

    struct Member: Codable {
        private let _default: String?
        let name: String
        private let _required: Bool?
        private let _nullable: Bool?
        private let _document: String
        let example: String?
        let member: String
        let type: APIObject.`Type`

        var document: String { self._document == "无" ? "" : self._document }
        var required: Bool { self._required ?? true }
        var nullable: Bool { self._nullable ?? false }
        var optional: Bool { !self.required || self.nullable }

        var `default`: String? {
            switch self._default {
            case "", "无", "NO", nil:
                return nil
            case #"“”"#, #""""#:
                // There's no valid use case for these empty string values now, so return nil instead.
                return nil
            default:
                return self._default
            }
        }

        enum CodingKeys: String, CodingKey {
            case _default = "default"
            case name
            case _required = "required"
            case _nullable = "value_allowed_null"
            case _document = "document"
            case example
            case member
            case type
        }
    }

    enum `Type`: String, Codable {
        case bool
        case int
        case float
        case string
        
        case binary

        case list
        case object
    }
}
