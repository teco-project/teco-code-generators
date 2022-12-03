import OrderedCollections
import TecoCodeGeneratorCommons

protocol CommonErrors {
    // https://cloud.tencent.com/document/product/1278/55263
    static var tcErrors: [ErrorCode : String] { get }

    // https://www.tencentcloud.com/document/api/213/31576#common-error-codes
    static var tcIntlErrors: [ErrorCode : String] { get }
}

enum ServerErrors: CommonErrors {
    static let tcErrors: [ErrorCode : String] = [
        "InternalError": "内部错误。",
        "ServiceUnavailable": "当前服务暂时不可用。",
        "ResponseSizeLimitExceeded": "返回包超过限制大小。",
    ]

    static let tcIntlErrors: [ErrorCode : String] = [
        "InternalError": "Internal error.",
    ]
}

enum ClientErrors: CommonErrors {
    static let tcErrors: [ErrorCode : String] = [
        "ActionOffline": "接口已下线。",
        "AuthFailure.InvalidAuthorization": "请求头部的Authorization不符合腾讯云标准。",
        "AuthFailure.InvalidSecretId": "密钥非法（不是云API密钥类型）。",
        "AuthFailure.MFAFailure": "MFA错误。",
        "AuthFailure.SecretIdNotFound": "密钥不存在。请在控制台检查密钥是否已被删除或者禁用，如状态正常，请检查密钥是否填写正确，注意前后不得有空格。",
        "AuthFailure.SignatureExpire": "签名过期。Timestamp和服务器时间相差不得超过五分钟，请检查本地时间是否和标准时间同步。",
        "AuthFailure.SignatureFailure": "签名错误。签名计算错误，请对照调用方式中的签名方法文档检查签名计算过程。",
        "AuthFailure.TokenFailure": "token错误。",
        "AuthFailure.UnauthorizedOperation": "请求未授权。请参考CAM文档对鉴权的说明。",
        "DryRunOperation": "DryRun操作，代表请求将会是成功的，只是多传了DryRun参数。",
        "FailedOperation": "操作失败。",
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
        "UnauthorizedOperation": "未授权操作。",
        "UnknownParameter": "未知参数错误，用户多传未定义的参数会导致错误。",
        "UnsupportedOperation": "操作不支持。",
        "UnsupportedProtocol": "http(s)请求协议错误，只支持GET和POST请求。",
        "UnsupportedRegion": "接口不支持所传地域。"
    ]

    static let tcIntlErrors: [ErrorCode : String] = [
        "AuthFailure.InvalidSecretId": "Invalid key (not a TencentCloud API key type).",
        "AuthFailure.MFAFailure": "MFA failed.",
        "AuthFailure.SecretIdNotFound": "The key does not exist.",
        "AuthFailure.SignatureExpire": "Signature expired.",
        "AuthFailure.SignatureFailure": "Signature error.",
        "AuthFailure.TokenFailure": "Token error.",
        "AuthFailure.UnauthorizedOperation": "The request does not have CAM authorization.",
        "DryRunOperation": "DryRun Operation. It means that the request would have succeeded, but the DryRun parameter was used.",
        "FailedOperation": "Operation failed.",
        "InvalidAction": "The API does not exist.",
        "InvalidParameter": "Incorrect parameter.",
        "InvalidParameterValue": "Invalid parameter value.",
        "LimitExceeded": "Quota limit exceeded.",
        "MissingParameter": "A parameter is missing.",
        "NoSuchVersion": "The API version does not exist.",
        "RequestLimitExceeded": "The number of requests exceeds the frequency limit.",
        "ResourceInUse": "Resource is in use.",
        "ResourceInsufficient": "Insufficient resource.",
        "ResourceNotFound": "The resource does not exist.",
        "ResourceUnavailable": "Resource is unavailable.",
        "UnauthorizedOperation": "Unauthorized operation.",
        "UnknownParameter": "Unknown parameter.",
        "UnsupportedOperation": "Unsupported operation.",
        "UnsupportedProtocol": "HTTPS request method error. Only GET and POST requests are supported.",
        "UnsupportedRegion": "API does not support the requested region.",
    ]
}
