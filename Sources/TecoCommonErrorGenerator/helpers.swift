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

func formatErrorSolution(_ solution: String) -> String {
    var lines = solution.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    guard let index = lines.firstIndex(where: \.isEmpty) else {
        return solution
    }
    precondition(index.isMultiple(of: 2))
    for i in 0..<index {
        lines[i] = i.isMultiple(of: 2) ? "- \(lines[i])" : "  \(lines[i])"
    }
    return lines.joined(separator: "\n")
}
