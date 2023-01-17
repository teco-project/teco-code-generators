@_implementationOnly import OrderedCollections

typealias RegionId = String

func getRegionMap(from regionInfo: [RegionInfo]) -> OrderedDictionary<RegionId, String> {
    let regions = regionInfo.map { ($0.region, $0.regionName) }
    return .init(uncheckedUniqueKeysWithValues: regions)
}

func getRegionDescriptionMaps(from maps: OrderedDictionary<RegionId, String>...) -> [(id: RegionId, names: OrderedSet<String>)] {
    let regionIds = maps.map(\.keys).reduce(OrderedSet(), { $0.union($1) })
    return regionIds.map { id in (id, OrderedSet(maps.compactMap({ $0[id] }))) }
}

extension RegionId {
    var kind: String? {
        if self.hasSuffix("-fsi") {
            return "financial"
        }
        if self.hasSuffix("-adc") {
            return "autoDriving"
        }
        if self.hasSuffix("-xinan") || self.hasSuffix("-sycft") {
            return "internal"
        }
        return nil
    }
}
