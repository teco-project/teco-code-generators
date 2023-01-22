// https://cloud.tencent.com/document/product/213/30435#.E5.85.AC.E5.85.B1.E9.94.99.E8.AF.AF.E7.A0.81
let tcCommonErrors: [ErrorCode : String] = [
    "ActionOffline": "接口已下线。",
    "AuthFailure.InvalidAuthorization": "请求头部的`Authorization`不符合腾讯云标准。",
    "AuthFailure.InvalidSecretId": "密钥非法（不是云API密钥类型）。",
    "AuthFailure.MFAFailure": "[MFA](https://cloud.tencent.com/document/product/378/12036)错误。",
    "AuthFailure.SecretIdNotFound": "密钥不存在。请在[控制台](https://console.cloud.tencent.com/cam/capi)检查密钥是否已被删除或者禁用，如状态正常，请检查密钥是否填写正确，注意前后不得有空格。",
    "AuthFailure.SignatureExpire": "签名过期。Timestamp和服务器时间相差不得超过五分钟，请检查本地时间是否和标准时间同步。",
    "AuthFailure.SignatureFailure": "签名错误。签名计算错误，请对照调用方式中的签名方法文档检查签名计算过程。",
    "AuthFailure.TokenFailure": "token错误。",
    "AuthFailure.UnauthorizedOperation": "请求未授权。请参考[CAM](https://cloud.tencent.com/document/product/598)文档对鉴权的说明。",
    "DryRunOperation": "DryRun操作，代表请求将会是成功的，只是多传了DryRun参数。",
    "FailedOperation": "操作失败。",
    "InternalError": "内部错误。",
    "InvalidAction": "接口不存在。",
    "InvalidParameter": "参数错误（包括参数格式、类型等错误）。",
    "InvalidParameterValue": "参数取值错误。",
    "InvalidRequest": "请求body的multipart格式错误。",
    "IpInBlacklist": "IP地址在黑名单中。",
    "IpNotInWhitelist": "IP地址不在白名单中。",
    "LimitExceeded": "超过配额限制。",
    "MissingParameter": "缺少参数。",
    "NoSuchProduct": "产品不存在。",
    "NoSuchVersion": "接口版本不存在。",
    "RequestLimitExceeded": "请求的次数超过了频率限制。",
    "RequestLimitExceeded.GlobalRegionUinLimitExceeded": "主账号超过频率限制。",
    "RequestLimitExceeded.IPLimitExceeded": "IP限频。",
    "RequestLimitExceeded.UinLimitExceeded": "主账号限频。",
    "RequestSizeLimitExceeded": "请求包超过限制大小。",
    "ResourceInUse": "资源被占用。",
    "ResourceInsufficient": "资源不足。",
    "ResourceNotFound": "资源不存在。",
    "ResourceUnavailable": "资源不可用。",
    "ResponseSizeLimitExceeded": "返回包超过限制大小。",
    "ServiceUnavailable": "当前服务暂时不可用。",
    "UnauthorizedOperation": "未授权操作。",
    "UnknownParameter": "未知参数错误，用户多传未定义的参数会导致错误。",
    "UnsupportedOperation": "操作不支持。",
    "UnsupportedProtocol": "http(s)请求协议错误，只支持GET和POST请求。",
    "UnsupportedRegion": "接口不支持所传地域。"
]

// https://www.tencentcloud.com/document/product/213/33281#common-error-codes
let tcIntlCommonErrors: [ErrorCode : String] = [
    "ActionOffline": "This API has been deprecated.",
    "AuthFailure.InvalidAuthorization": "`Authorization` in the request header is invalid.",
    "AuthFailure.InvalidSecretId": "Invalid key (not a TencentCloud API key type).",
    "AuthFailure.MFAFailure": "MFA failed.",
    "AuthFailure.SecretIdNotFound": "Key does not exist. Check if the key has been deleted or disabled in the console, and if not, check if the key is correctly entered. Note that whitespaces should not exist before or after the key.",
    "AuthFailure.SignatureExpire": "Signature expired. Timestamp and server time cannot differ by more than five minutes. Please ensure your current local time matches the standard time.",
    "AuthFailure.SignatureFailure": "Invalid signature. Signature calculation error. Please ensure you’ve followed the signature calculation process described in the Signature API documentation.",
    "AuthFailure.TokenFailure": "Token error.",
    "AuthFailure.UnauthorizedOperation": "The request is not authorized. For more information, see the [CAM](https://www.tencentcloud.com/document/product/598) documentation.",
    "DryRunOperation": "DryRun Operation. It means that the request would have succeeded, but the DryRun parameter was used.",
    "FailedOperation": "Operation failed.",
    "InternalError": "Internal error.",
    "InvalidAction": "The API does not exist.",
    "InvalidParameter": "Incorrect parameter.",
    "InvalidParameterValue": "Invalid parameter value.",
    "InvalidRequest": "The multipart format of the request body is incorrect.",
    "IpInBlacklist": "Your IP is in uin IP blacklist.",
    "IpNotInWhitelist": "Your IP is not in uin IP whitelist.",
    "LimitExceeded": "Quota limit exceeded.",
    "MissingParameter": "A parameter is missing.",
    "NoSuchProduct": "The product does not exist.",
    "NoSuchVersion": "The API version does not exist.",
    "RequestLimitExceeded": "The number of requests exceeds the frequency limit.",
    "RequestLimitExceeded.GlobalRegionUinLimitExceeded": "Uin exceeds the frequency limit.",
    "RequestLimitExceeded.IPLimitExceeded": "The number of ip requests exceeds the frequency limit.",
    "RequestLimitExceeded.UinLimitExceeded": "The number of uin requests exceeds the frequency limit.",
    "RequestSizeLimitExceeded": "The request size exceeds the upper limit.",
    "ResourceInUse": "Resource is in use.",
    "ResourceInsufficient": "Insufficient resource.",
    "ResourceNotFound": "The resource does not exist.",
    "ResourceUnavailable": "Resource is unavailable.",
    "ResponseSizeLimitExceeded": "The response size exceeds the upper limit.",
    "ServiceUnavailable": "Service is unavailable now.",
    "UnauthorizedOperation": "Unauthorized operation.",
    "UnknownParameter": "Unknown parameter.",
    "UnsupportedOperation": "Unsupported operation.",
    "UnsupportedProtocol": "HTTP(S) request protocol error; only GET and POST requests are supported.",
    "UnsupportedRegion": "API does not support the requested region.",
]

struct APIError: Codable {
    let productShortName: String
    let productVersion: String
    let code: String
    let description: String?
    private let _solution: String
    let productCNName: String?

    var solution: String? {
        switch self._solution {
        case "无", "暂无", "占位符":
            return nil
        case "业务正在更新中，请您耐心等待。":
            return nil
        default:
            return self._solution.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\r\n", with: "\n")
        }
    }

    enum CodingKeys: String, CodingKey {
        case productShortName = "productName"
        case productVersion
        case code
        case description
        case _solution = "solution"
        case productCNName
    }
}
