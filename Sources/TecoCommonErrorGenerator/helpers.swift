import ArgumentParser
import Foundation
@_implementationOnly import OrderedCollections

struct CommonError {
    let code: String
    var identifier: String { self.code.lowerFirst().replacingOccurrences(of: ".", with: "_") }
    let description: [String]
    let solution: String?
}

func getErrorCodes() -> [String] {
    return OrderedSet(tcCommonErrors.keys).union(tcIntlCommonErrors.keys).sorted()
}

func getAPIErrors(from file: URL?) throws -> [APIError] {
    if let file {
        return try JSONDecoder().decode([APIError].self, from: .init(contentsOf: file))
                .filter { $0.productShortName == "PLATFORM" }
    } else {
        return []
    }
}

func getCommonError(from code: String, apiErrors: [APIError] = []) -> CommonError {
    let description = [tcIntlCommonErrors[code], tcCommonErrors[code]].compactMap { $0 }
    precondition(description.isEmpty == false)
    let solution = apiErrors.first(where: { $0.code == code })?.solution
    return CommonError(code: code, description: description, solution: solution)
}

func getCommonErrors(from codes: [String], apiErrors: [APIError] = []) -> [CommonError] {
    return codes.map { getCommonError(from: $0, apiErrors: apiErrors) }
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
