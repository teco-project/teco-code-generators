@_implementationOnly import OrderedCollections
@_implementationOnly import TecoCore

func getRegionMap(from regionInfo: [RegionInfo]) -> OrderedDictionary<String, String> {
    let regions = regionInfo.map { ($0.region, $0.regionName) }
    return .init(uncheckedUniqueKeysWithValues: regions)
}

private struct DescribeRegionsRequest: TCRequestModel {
    let product: String

    enum CodingKeys: String, CodingKey {
        case product = "Product"
    }
}

private struct DescribeRegionsResponse: TCResponseModel {
    let totalCount: UInt64
    let regionSet: [RegionInfo]
    let requestId: String

    enum CodingKeys: String, CodingKey {
        case totalCount = "TotalCount"
        case regionSet = "RegionSet"
        case requestId = "RequestId"
    }
}

struct RegionInfo: TCOutputModel {
    let region: String
    let regionName: String
    let regionState: String

    enum CodingKeys: String, CodingKey {
        case region = "Region"
        case regionName = "RegionName"
        case regionState = "RegionState"
    }
}

struct Region: TCService {
    let client: TCClient
    let config: TCServiceConfig

    init() {
        self.client = TCClient(httpClientProvider: .createNew)
        self.config = TCServiceConfig(service: "region", version: "2022-06-27")
    }

    init(from service: Self, patch: TCServiceConfig.Patch) {
        self.client = service.client
        self.config = service.config.with(patch: patch)
    }

    func shutdown() throws {
        try self.client.syncShutdown()
    }

    func describeRegions(for product: String) async throws -> [RegionInfo] {
        let request = DescribeRegionsRequest(product: product)
        let response: DescribeRegionsResponse = try await self.client.execute(action: "DescribeRegions", serviceConfig: self.config, input: request).get()
        return response.regionSet
    }
}
