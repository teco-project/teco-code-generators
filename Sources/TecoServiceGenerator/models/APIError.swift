struct APIError: Codable {
    let productShortName: String
    let productVersion: String
    let code: String
    private let _description: String?
    private let _solution: String
    let productCNName: String?

    var description: String? { formatErrorDescription(self._description) }

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
        case productShortName = "productName"
        case productVersion
        case code
        case _description = "description"
        case _solution = "solution"
        case productCNName
    }
}

extension APIError {
    var identifier: String {
        self.code.lowerFirst().replacingOccurrences(of: ".", with: "_")
    }

    func identifier(for domain: String) -> String? {
        let components = self.code.split(separator: ".").map(String.init)
        guard components[0] == domain else {
            return nil
        }
        return components.count == 1 ? "other" : components[1].lowerFirst()
    }
}
