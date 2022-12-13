import ArgumentParser
@_implementationOnly import OrderedCollections

typealias ErrorCode = String
typealias ErrorDefinition = (code: ErrorCode, identifier: String, description: [String])

func getErrorCodes() -> [ErrorCode] {
    return OrderedSet(tcCommonErrors.keys).union(tcIntlCommonErrors.keys).sorted()
}

func getErrorDefinition(from code: ErrorCode) -> ErrorDefinition {
    let desc = [tcIntlCommonErrors[code], tcCommonErrors[code]].compactMap { $0 }
    precondition(desc.isEmpty == false)
    return (code, code.lowerFirst().replacingOccurrences(of: ".", with: "_"), desc)
}

func getErrorDefinitions(from codes: [ErrorCode]? = nil) -> [ErrorDefinition] {
    let codes = codes ?? getErrorCodes()
    return codes.map(getErrorDefinition)
}
