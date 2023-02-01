@_implementationOnly import OrderedCollections

typealias RegionId = String

func getRegionMap(from regionInfo: [RegionInfo]) -> OrderedDictionary<RegionId, String> {
    let regions = regionInfo.map { ($0.region, $0.regionName) }
    return .init(uncheckedUniqueKeysWithValues: regions)
}

func getRegions(from maps: OrderedDictionary<RegionId, String>...) -> OrderedSet<Region> {
    let baseKeys = maps[0].keys
    if maps.count > 1 {
        for map in maps[1...] {
            precondition(map.keys == baseKeys)
        }
    }
    return OrderedSet(baseKeys.map { id in
        Region(id: id, localizedNames: OrderedSet(maps.map { $0[id]! }))
    })
}

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
