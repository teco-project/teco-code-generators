struct APIModel: Codable {
    let actions: [String : Action]
    let metadata: Metadata
    let objects: [String : APIObject]
    let version: String

    struct Action: Codable {
        let name: String
        let document: String
        let input: String
        let output: String
    }

    struct Metadata: Codable {
        let version: String
        let brief: String?
        let serviceName: String
        let shortName: String

        enum CodingKeys: String, CodingKey {
            case version = "apiVersion"
            case brief = "api_brief"
            case serviceName = "serviceNameCN"
            case shortName = "serviceShortName"
        }
    }
}
