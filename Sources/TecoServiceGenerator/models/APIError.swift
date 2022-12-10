struct APIError: Codable {
    let productName: String
    let productVersion: String
    let code: String
    let description: String?
    // 无效值 "业务正在更新中，请您耐心等待。"
    let solution: String
    let productCNName: String?
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
