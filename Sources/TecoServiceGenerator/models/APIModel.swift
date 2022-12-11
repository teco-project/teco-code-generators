struct APIModel: Codable {
    let actions: [String : Action]
    let metadata: Metadata
    let objects: [String : APIObject]
    let version: String

    var namespace: String { metadata.shortName.upperFirst() }

    struct Action: Codable {
        let name: String
        let document: String
        let input: String
        let output: String
    }

    struct Metadata: Codable {
        let version: String
        private let _brief: String?
        let serviceName: String?
        let shortName: String

        var document: String? {
            guard let brief = self._brief, !brief.isEmpty else { return nil }
            for prefix in ["介绍如何使用API"] where brief.hasPrefix(prefix) {
                return String(brief.dropFirst(prefix.count))
            }
            return brief
        }

        enum CodingKeys: String, CodingKey {
            case version = "apiVersion"
            case _brief = "api_brief"
            case serviceName = "serviceNameCN"
            case shortName = "serviceShortName"
        }
    }
}
