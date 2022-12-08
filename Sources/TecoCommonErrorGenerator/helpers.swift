import ArgumentParser
@_implementationOnly import OrderedCollections

typealias ErrorCode = String
typealias ErrorDefinition = (code: ErrorCode, identifier: String, description: [String])

func getErrorCodes() -> [ErrorCode] {
    return OrderedSet(tcCommonErrors.keys).union(tcIntlCommonErrors.keys).sorted()
}

func getErrorDefinition(from code: ErrorCode) -> ErrorDefinition {
    let desc = [tcIntlCommonErrors[code], tcCommonErrors[code]].compactMap { $0 }
    assert(desc.isEmpty == false)
    return (code, code.lowerFirst().replacingOccurrences(of: ".", with: "_"), desc)
}

func getErrorDefinitions(from codes: [ErrorCode]? = nil) -> [ErrorDefinition] {
    let codes = codes ?? getErrorCodes()
    return codes.map(getErrorDefinition)
}

func getErrorDomain(from code: ErrorCode) -> ErrorCode? {
    let components = code.split(separator: ".")
    guard components.count >= 2 else {
        return nil
    }
    precondition(components.count == 2)
    return .init(components[0])
}

func getErrorDomains(from codes: [ErrorCode]? = nil) -> [ErrorCode]  {
    let codes = codes ?? getErrorCodes()
    let domains = OrderedSet(codes.compactMap(getErrorDomain))
    return domains.sorted()
}

func getDomainedErrorDefinition(from error: ErrorDefinition, domain: ErrorCode) -> ErrorDefinition? {
    let components = error.code.split(separator: ".").map(String.init)
    guard components[0] == domain else {
        return nil
    }
    return (error.code, components.count == 1 ? "other" : components[1].lowerFirst(), error.description)
}

func getDomainedErrorDefinitions(from errors: [ErrorDefinition]? = nil, domain: ErrorCode) -> [ErrorDefinition] {
    let errors = errors ?? getErrorDefinitions()
    var domainedErrors = errors.compactMap { getDomainedErrorDefinition(from: $0, domain: domain) }
    // Move `.other` to the last of the list
    if let otherIndex = domainedErrors.firstIndex(where: { $0.code == domain }) {
        let otherError = domainedErrors.remove(at: otherIndex)
        domainedErrors.append(otherError)
    }
    return domainedErrors
}
