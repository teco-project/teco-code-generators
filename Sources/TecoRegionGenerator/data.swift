// TODO: Generate definitions with TecoCodeGenerators and fetch with Teco.

import Foundation
@_implementationOnly import OrderedCollections

struct Region: Hashable {
    let id: String
    let localizedNames: OrderedSet<String>
}

struct RegionInfo: Codable {
    let region: String
    let regionName: String

    enum CodingKeys: String, CodingKey {
        case region = "Region"
        case regionName = "RegionName"
    }
}

let tcJSONString = """
    [
        {
            "Region": "ap-guangzhou",
            "RegionName": "华南地区(广州)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-shanghai",
            "RegionName": "华东地区(上海)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-nanjing",
            "RegionName": "华东地区(南京)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-hongkong",
            "RegionName": "港澳台地区(中国香港)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "na-toronto",
            "RegionName": "北美地区(多伦多)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-beijing",
            "RegionName": "华北地区(北京)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-singapore",
            "RegionName": "亚太东南(新加坡)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-bangkok",
            "RegionName": "亚太东南(曼谷)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-jakarta",
            "RegionName": "亚太东南(雅加达)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "na-siliconvalley",
            "RegionName": "美国西部(硅谷)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-chengdu",
            "RegionName": "西南地区(成都)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-chongqing",
            "RegionName": "西南地区(重庆)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "eu-frankfurt",
            "RegionName": "欧洲地区(法兰克福)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "eu-moscow",
            "RegionName": "欧洲地区(莫斯科)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-seoul",
            "RegionName": "亚太东北(首尔)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-tokyo",
            "RegionName": "亚太东北(东京)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-mumbai",
            "RegionName": "亚太南部(孟买)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "na-ashburn",
            "RegionName": "美国东部(弗吉尼亚)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "sa-saopaulo",
            "RegionName": "南美地区(圣保罗)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        }
    ]
    """

let tcIntlJSONString = """
    [
        {
            "Region": "ap-guangzhou",
            "RegionName": "South China(Guangzhou)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-shanghai",
            "RegionName": "East China(Shanghai)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-nanjing",
            "RegionName": "East China(Nanjing)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-hongkong",
            "RegionName": "Hong Kong, Macau and Taiwan (China)(Hong Kong, China)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "na-toronto",
            "RegionName": "North America(Toronto)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-beijing",
            "RegionName": "North China region(Beijing)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-singapore",
            "RegionName": "Southeast Asia(Singapore)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-bangkok",
            "RegionName": "Southeast Asia(Bangkok)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-jakarta",
            "RegionName": "Southeast Asia(Jakarta)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "na-siliconvalley",
            "RegionName": "US West(Silicon Valley)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-chengdu",
            "RegionName": "Southwest China(Chengdu)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-chongqing",
            "RegionName": "Southwest China(Chongqing)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "eu-frankfurt",
            "RegionName": "Europe(Frankfurt)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "eu-moscow",
            "RegionName": "Europe(Northeastern Europe)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-seoul",
            "RegionName": "Northeast Asia(Seoul)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-tokyo",
            "RegionName": "Northeast Asia(Tokyo)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "ap-mumbai",
            "RegionName": "South Asia(Mumbai)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "na-ashburn",
            "RegionName": "US East(Virginia)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        },
        {
            "Region": "sa-saopaulo",
            "RegionName": "South America(São Paulo)",
            "RegionState": "AVAILABLE",
            "RegionTypeMC": null,
            "LocationMC": null,
            "RegionNameMC": null,
            "RegionIdMC": null
        }
    ]
"""

private let tcRegions = try! JSONDecoder().decode([RegionInfo].self, from: tcJSONString.data(using: .utf8)!)
private let tcIntlRegions = try! JSONDecoder().decode([RegionInfo].self, from: tcIntlJSONString.data(using: .utf8)!)
let regions = getRegions(from: getRegionMap(from: tcIntlRegions), getRegionMap(from: tcRegions))
