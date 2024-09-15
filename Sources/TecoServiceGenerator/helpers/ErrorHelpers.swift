#if compiler(>=6.0)
internal import OrderedCollections
private import RegexBuilder
#else
@_implementationOnly import OrderedCollections
@_implementationOnly import RegexBuilder
#endif

func getErrorDomain(from code: String) -> String? {
    let components = code.split(separator: ".")
    guard components.count >= 2 else {
        return nil
    }
    precondition(components.count == 2)
    return .init(components[0])
}

func getErrorDomains(from errors: [APIError]) -> [String] {
    let domains = OrderedSet(errors.map(\.code).compactMap(getErrorDomain))
    return domains.sorted()
}

func generateErrorMap(from errors: [APIError]) -> OrderedDictionary<String, APIError> {
    var errorMap: OrderedDictionary<String, APIError> = [:]

    for error in errors {
        errorMap[error.identifier] = error
    }
    errorMap.sort()

    return errorMap
}

func generateDomainedErrorMap(from errors: [APIError], for domain: String) -> OrderedDictionary<String, APIError> {
    let errors = errors.filter { $0.code.hasPrefix(domain) }
    var errorMap: OrderedDictionary<String, APIError> = [:]
    
    for error in errors {
        if let identifier = error.identifier(for: domain) {
            errorMap[identifier] = error
        }
    }
    errorMap.sort()
    
    if let otherError = errorMap["other"] {
        errorMap.removeValue(forKey: "other")
        errorMap.updateValue(otherError, forKey: "other")
    }
    
    return errorMap
}

func formatErrorDescription(_ description: String?) -> String? {
    let codeTagRegex = Regex {
        "<code>"
        Capture(OneOrMore(.any, .reluctant))
        "</code>"
    }
    let aTagRegex = Regex {
        "<a href=\""
        Capture(OneOrMore(.any, .reluctant))
        "\">"
        Capture(OneOrMore(.any, .reluctant))
        "</a>"
    }
    return description?
        .replacing(codeTagRegex) { match in
            "`\(match.1)`"
        }
        .replacing(aTagRegex) { match in
            "[\(match.2)](\(match.1))"
        }
}
