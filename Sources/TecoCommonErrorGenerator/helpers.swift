import ArgumentParser
@_implementationOnly import OrderedCollections

typealias ErrorCode = String
typealias ErrorDefinition = (code: ErrorCode, identifier: String, description: [String], solution: String?)

func docComment(_ document: String?) -> String {
    return (document ?? "")
        .split(whereSeparator: \.isNewline)
        .map { "/// \($0)" }.joined(separator: "\n")
}

func docComment(summary: String?, discussion: String?) -> String {
    var document: [String] = []
    if let summary, !summary.isEmpty {
        document.append("/// \(summary.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    if case let discussion = docComment(discussion), !discussion.isEmpty {
        document.append(discussion.replacingOccurrences(of: "\n", with: "\n///\n"))
    }
    return OrderedSet(document).joined(separator: "\n///\n")
}

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
