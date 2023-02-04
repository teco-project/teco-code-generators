struct APIModel: Codable {
    let actions: [String : Action]
    let metadata: Metadata
    let objects: [String : APIObject]
    let version: String

    var namespace: String { metadata.shortName.upperFirst() }

    struct Action: Codable {
        let name: String
        private let _document: String
        let input: String
        let output: String
        private let _status: Status?

        var status: Status { self._status ?? .online }
        var availability: String? {
            switch self.status {
            case .online:
                return nil
            case .offline:
                return "deprecated"
            case .deprecated:
                return "unavailable"
            }
        }

        var document: String {
            if let deprecationMessage {
                return self._document.dropFirst(deprecationMessage.count).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return self._document.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        var deprecationMessage: String? {
            guard self.status != .online else { return nil }
            if #available(macOS 13, *) {
                return self._document.split(separator: "\n\n").first.map(String.init)
            } else {
                // message may be stripped since this platform doesn't support Regex...
                return self._document.split(whereSeparator: \.isNewline).first.map(String.init)
            }
        }

        enum CodingKeys: String, CodingKey {
            case name
            case _document = "document"
            case input
            case output
            case _status = "status"
        }

        enum Status: String, Codable {
            case online
            case offline
            case deprecated
        }
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
