import ArgumentParser
import Foundation

struct CommonError {
    let code: String
    let description: String
    let solution: String?

    var identifier: String { self.code.lowerFirst().replacingOccurrences(of: ".", with: "_") }
}

struct APIError: Codable {
    let product: String
    let code: String
    private let _solution: String

    var solution: String? {
        switch self._solution {
        case "无", "暂无", "占位符":
            return nil
        case "业务正在更新中，请您耐心等待。":
            return nil
        default:
            return self._solution.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\r\n", with: "\n")
        }
    }

    enum CodingKeys: String, CodingKey {
        case product = "productName"
        case code
        case _solution = "solution"
    }
}

func getAPIErrors(from file: URL?) throws -> [APIError] {
    if let file {
        return try JSONDecoder().decode([APIError].self, from: .init(contentsOf: file))
                .filter { $0.product == "PLATFORM" }
    } else {
        return []
    }
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
