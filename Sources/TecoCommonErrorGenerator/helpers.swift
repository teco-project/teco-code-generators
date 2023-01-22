import ArgumentParser
@_implementationOnly import OrderedCollections

typealias ErrorCode = String
typealias ErrorDefinition = (code: ErrorCode, identifier: String, description: [String], solution: String?)

func getErrorCodes() -> [ErrorCode] {
    return OrderedSet(tcCommonErrors.keys).union(tcIntlCommonErrors.keys).sorted()
}

func getErrorDefinition(from code: ErrorCode, apiErrors: [APIError] = []) -> ErrorDefinition {
    let desc = [tcIntlCommonErrors[code], tcCommonErrors[code]].compactMap { $0 }
    precondition(desc.isEmpty == false)
    return (code, code.lowerFirst().replacingOccurrences(of: ".", with: "_"), desc, apiErrors.first { $0.code == code }?.solution)
}

func getErrorDefinitions(from codes: [ErrorCode], apiErrors: [APIError] = []) -> [ErrorDefinition] {
    return codes.map { getErrorDefinition(from: $0, apiErrors: apiErrors) }
}
