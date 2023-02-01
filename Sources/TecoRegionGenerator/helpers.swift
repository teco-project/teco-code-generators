extension Region: Equatable, Comparable {
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

    static func == (lhs: Region, rhs: Region) -> Bool {
        lhs.id == rhs.id
    }
    static func < (lhs: Region, rhs: Region) -> Bool {
        lhs.id < rhs.id
    }
}
