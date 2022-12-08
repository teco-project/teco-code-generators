// TODO: Generate definitions with TecoCodeGenerators and fetch with Teco.

import Foundation

struct RegionInfo: Codable {
    let region: String
    let regionName: String
    let regionState: String

    enum CodingKeys: String, CodingKey {
        case region = "Region"
        case regionName = "RegionName"
        case regionState = "RegionState"
    }
}

let tcJSONString = """
    [
        {
            "Region": "ap-guangzhou",
            "RegionName": "华南地区(广州)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shenzhen-fsi",
            "RegionName": "华南地区(深圳金融)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-guangzhou-open",
            "RegionName": "华南地区(广州OPEN)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-qingyuan",
            "RegionName": "华南地区(清远)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-qingyuan-xinan",
            "RegionName": "华南地区(清远信安)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shenzhen-sycft",
            "RegionName": "华南地区(深圳深宇财付通)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shanghai",
            "RegionName": "华东地区(上海)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shanghai-fsi",
            "RegionName": "华东地区(上海金融)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-jinan-ec",
            "RegionName": "华东地区(济南)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-hangzhou-ec",
            "RegionName": "华东地区(杭州)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-nanjing",
            "RegionName": "华东地区(南京)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-fuzhou-ec",
            "RegionName": "华东地区(福州)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-hefei-ec",
            "RegionName": "华东地区(合肥)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shanghai-adc",
            "RegionName": "华东地区(上海自动驾驶云)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-hongkong",
            "RegionName": "港澳台地区(中国香港)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-taipei",
            "RegionName": "港澳台地区(中国台北)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "na-toronto",
            "RegionName": "北美地区(多伦多)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-beijing",
            "RegionName": "华北地区(北京)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-beijing-fsi",
            "RegionName": "华北地区(北京金融)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shijiazhuang-ec",
            "RegionName": "华北地区(石家庄)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-singapore",
            "RegionName": "亚太东南(新加坡)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-bangkok",
            "RegionName": "亚太东南(曼谷)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-jakarta",
            "RegionName": "亚太东南(雅加达)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "na-siliconvalley",
            "RegionName": "美国西部(硅谷)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-chengdu",
            "RegionName": "西南地区(成都)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-chongqing",
            "RegionName": "西南地区(重庆)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-guiyang",
            "RegionName": "西南地区(贵阳)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "eu-frankfurt",
            "RegionName": "欧洲地区(法兰克福)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "eu-moscow",
            "RegionName": "欧洲地区(莫斯科)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-seoul",
            "RegionName": "亚太东北(首尔)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-tokyo",
            "RegionName": "亚太东北(东京)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-mumbai",
            "RegionName": "亚太南部(孟买)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "na-ashburn",
            "RegionName": "美国东部(弗吉尼亚)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-wuhan-ec",
            "RegionName": "华中地区(武汉)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-changsha-ec",
            "RegionName": "华中地区(长沙)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-zhengzhou-ec",
            "RegionName": "华中地区(郑州)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shenyang-ec",
            "RegionName": "东北地区(沈阳)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-xian-ec",
            "RegionName": "西北地区(西安)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-xibei-ec",
            "RegionName": "西北地区(西北)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "sa-saopaulo",
            "RegionName": "南美地区(圣保罗)",
            "RegionState": "AVAILABLE"
        }
    ]
    """

let tcIntlJSONString = """
    [
        {
            "Region": "ap-guangzhou",
            "RegionName": "South China(Guangzhou)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shenzhen-fsi",
            "RegionName": "South China(Shenzhen Finance)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-guangzhou-open",
            "RegionName": "South China(Guangzhou OPEN)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-qingyuan",
            "RegionName": "South China(Qingyuan)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-qingyuan-xinan",
            "RegionName": "South China(Qingyuan Xinan)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shenzhen-sycft",
            "RegionName": "South China(Shenzhen Shenyu Tenpay)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shanghai",
            "RegionName": "East China(Shanghai)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shanghai-fsi",
            "RegionName": "East China(Shanghai Finance)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-jinan-ec",
            "RegionName": "East China(Jinan)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-hangzhou-ec",
            "RegionName": "East China(Hangzhou)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-nanjing",
            "RegionName": "East China(Nanjing)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-fuzhou-ec",
            "RegionName": "East China(Fuzhou)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-hefei-ec",
            "RegionName": "East China(Hefei)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shanghai-adc",
            "RegionName": "East China(Shanghai Self-driving Cloud)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-hongkong",
            "RegionName": "Hong Kong, Macau and Taiwan (China)(Hong Kong, China)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-taipei",
            "RegionName": "Hong Kong, Macau and Taiwan (China)(Taiwan, China)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "na-toronto",
            "RegionName": "North America(Toronto)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-beijing",
            "RegionName": "North China region(Beijing)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-beijing-fsi",
            "RegionName": "North China region(Beijing Finance)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shijiazhuang-ec",
            "RegionName": "North China region(Shijiazhuang)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-singapore",
            "RegionName": "Southeast Asia(Singapore)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-bangkok",
            "RegionName": "Southeast Asia(Bangkok)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-jakarta",
            "RegionName": "Southeast Asia(Jakarta)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "na-siliconvalley",
            "RegionName": "US West(Silicon Valley)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-chengdu",
            "RegionName": "Southwest China(Chengdu)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-chongqing",
            "RegionName": "Southwest China(Chongqing)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-guiyang",
            "RegionName": "Southwest China(Guiyang)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "eu-frankfurt",
            "RegionName": "Europe(Frankfurt)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "eu-moscow",
            "RegionName": "Europe(Northeastern Europe)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-seoul",
            "RegionName": "Northeast Asia(Seoul)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-tokyo",
            "RegionName": "Northeast Asia(Tokyo)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-mumbai",
            "RegionName": "South Asia(Mumbai)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "na-ashburn",
            "RegionName": "US East(Virginia)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-wuhan-ec",
            "RegionName": "Central China(Wuhan)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-changsha-ec",
            "RegionName": "Central China(Changsha)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-zhengzhou-ec",
            "RegionName": "Central China(Zhengzhou)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-shenyang-ec",
            "RegionName": "Northeast China(Shenyang)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-xian-ec",
            "RegionName": "Northwest region(Xi'an)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "ap-xibei-ec",
            "RegionName": "Northwest region(Northwest China)",
            "RegionState": "AVAILABLE"
        },
        {
            "Region": "sa-saopaulo",
            "RegionName": "South America(São Paulo)",
            "RegionState": "AVAILABLE"
        }
    ]
"""

let tcRegions = try! JSONDecoder().decode([RegionInfo].self, from: tcJSONString.data(using: .utf8)!)
let tcIntlRegions = try! JSONDecoder().decode([RegionInfo].self, from: tcIntlJSONString.data(using: .utf8)!)
