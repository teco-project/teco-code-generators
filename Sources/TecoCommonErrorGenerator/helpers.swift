import ArgumentParser
import OrderedCollections

typealias ErrorCode = String

enum ErrorType: String {
    case server = "TCServerError"
    case client = "TCClientError"
}

extension ErrorType: ExpressibleByArgument {
    init?(argument: String) {
        switch argument {
        case "server", "Server", "TCServerError":
            self = .server
        case "client", "Client", "TCClientError":
            self = .client
        default:
            return nil
        }
    }
}

extension ErrorType: CustomStringConvertible {
    var description: String { self.rawValue }
}

extension ErrorType {
    var `CommonErrors`: CommonErrors.Type {
        switch self {
        case .server:
            return ServerErrors.self
        case .client:
            return ClientErrors.self
        }
    }
}

func commonErrors(for type: ErrorType) -> OrderedDictionary<ErrorCode, [String]> {
    var result: OrderedDictionary<ErrorCode, [String]> = [:]
    let commonErrors = type.CommonErrors
    let keys = OrderedSet(commonErrors.tcErrors.keys).union(commonErrors.tcIntlErrors.keys)
    for key in keys.sorted() {
        result[key] = [commonErrors.tcIntlErrors[key], commonErrors.tcErrors[key]].compactMap { $0 }
        assert(result[key]?.isEmpty == false)
    }
    return result
}

func errorDomains(from errors: OrderedSet<ErrorCode>) -> OrderedDictionary<ErrorCode, [ErrorCode]> {
    var result: OrderedDictionary<ErrorCode, [ErrorCode]> = [:]
    for code in errors {
        let components = code.split(separator: ".").map(String.init)
        precondition(components.count <= 2)
        if components.count == 2 {
            var subErrors = result[components[0]] ?? []
            subErrors.append(components[1])
            result[components[0]] = subErrors.sorted()
        }
    }
    return result
}
