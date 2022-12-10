struct APIError: Codable {
    let productShortName: String
    let productVersion: String
    let code: String
    let description: String?
    private let _solution: String
    let productCNName: String?

    var solution: String? {
        self._solution == "业务正在更新中，请您耐心等待。" ? nil : self._solution
    }

    enum CodingKeys: String, CodingKey {
        case productShortName = "productName"
        case productVersion
        case code
        case description
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
