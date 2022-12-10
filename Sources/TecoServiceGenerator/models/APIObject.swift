struct APIObject: Codable {
    let document: String
    let members: [Member]
    private let _type: `Type`?
    var usage: Usage?

    var type: `Type` { self._type ?? .object }

    enum CodingKeys: String, CodingKey {
        case document
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
        let `default`: String?
        let name: String
        private let _required: Bool?
        private let _nullable: Bool?
        let document: String
        let example: String?
        let member: String
        let type: APIObject.`Type`

        var required: Bool { self._required ?? true }
        var nullable: Bool { self._nullable ?? false }

        enum CodingKeys: String, CodingKey {
            case `default`
            case name
            case _required = "required"
            case _nullable = "value_allowed_null"
            case document
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

        case list
        case object
    }
}
