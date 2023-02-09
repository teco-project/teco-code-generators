struct Region: Hashable {
    let id: String
    let localizedNames: [String]

    var description: String { self.localizedNames.joined(separator: " / ") }
    var identifier: String { self.id.replacingOccurrences(of: "-", with: "_") }
    var kind: String? {
        if self.id.hasSuffix("-fsi") {
            return "financial"
        }
        if self.id.hasSuffix("-adc") || self.id.hasSuffix("-sycft") || self.id.hasSuffix("-xinan") {
            return "internal"
        }
        return nil
    }
    
    init(id: String, localized: [String]) {
        self.id = id
        self.localizedNames = localized
    }
}

extension Region: Comparable {
    static func == (lhs: Region, rhs: Region) -> Bool {
        lhs.id == rhs.id
    }
    static func < (lhs: Region, rhs: Region) -> Bool {
        lhs.id < rhs.id
    }
}
