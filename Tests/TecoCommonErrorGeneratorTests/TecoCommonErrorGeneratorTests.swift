import TecoCodeGeneratorTestHelpers
import XCTest

#if Xcode // Works around FB11980900
@testable import teco_common_error_generator
#else
@testable import TecoCommonErrorGenerator
#endif

final class TecoCommonErrorGeneratorTests: XCTestCase {
    func testCommonErrorStructDeclBuilder() {
        let errors = [
            CommonError(code: "ActionOffline", description: "This API has been deprecated.\n接口已下线。", solution: nil),
            CommonError(
                code: "AuthFailure.SecretIdNotFound",
                description: """
                Key does not exist. Check if the key has been deleted or disabled in the console, and if not, check if the key is correctly entered. Note that whitespaces should not exist before or after the key.
                密钥不存在。请在[控制台](https://console.cloud.tencent.com/cam/capi)检查密钥是否已被删除或者禁用，如状态正常，请检查密钥是否填写正确，注意前后不得有空格。
                """,
                solution: """
                - The SecretId is not found, please ensure that your SecretId is correct.
                  SecretId不存在，请输入正确的密钥。
                
                当您接口返回这些错误时，说明您调接口时用的密钥信息不存在，请在控制台检查密钥是否已被删除或者禁用，如状态正常，请检查密钥是否填写正确，注意前后不得有空格。
                """
            ),
        ]
        AssertBuilder(buildCommonErrorStructDecl(from: errors), """
            /// Common error type returned by Tencent Cloud.
            public struct TCCommonError: TCServiceErrorType {
                enum Code: String {
                    case actionOffline = "ActionOffline"
                    case authFailure_SecretIdNotFound = "AuthFailure.SecretIdNotFound"
                }
            
                private let error: Code
            
                public let context: TCErrorContext?
            
                public var errorCode: String {
                    self.error.rawValue
                }
            
                public init?(errorCode: String, context: TCErrorContext) {
                    guard let error = Code(rawValue: errorCode) else {
                        return nil
                    }
                    self.error = error
                    self.context = context
                }
            
                public func asCommonError() -> TCCommonError? {
                    return self
                }
            
                internal init(_ error: Code, context: TCErrorContext? = nil) {
                    self.error = error
                    self.context = context
                }
            
                /// This API has been deprecated.
                /// 接口已下线。
                public static var actionOffline: TCCommonError {
                    TCCommonError(.actionOffline)
                }
            
                /// Key does not exist. Check if the key has been deleted or disabled in the console, and if not, check if the key is correctly entered. Note that whitespaces should not exist before or after the key.
                /// 密钥不存在。请在[控制台](https://console.cloud.tencent.com/cam/capi)检查密钥是否已被删除或者禁用，如状态正常，请检查密钥是否填写正确，注意前后不得有空格。
                ///
                /// - The SecretId is not found, please ensure that your SecretId is correct.
                ///   SecretId不存在，请输入正确的密钥。
                ///
                /// 当您接口返回这些错误时，说明您调接口时用的密钥信息不存在，请在控制台检查密钥是否已被删除或者禁用，如状态正常，请检查密钥是否填写正确，注意前后不得有空格。
                public static var authFailure_SecretIdNotFound: TCCommonError {
                    TCCommonError(.authFailure_SecretIdNotFound)
                }
            }
            """)
    }

    func testFormatErrorSolution() {
        let solution = """
            The provided credentials could not be validated. Please check your signature is correct.
            请求签名验证失败，请检查您的签名计算是否正确。
            The provided credentials could not be validated because of exceeding request size limit, please use new signature method `TC3-HMAC-SHA256`.
            由于请求包大小超过限制，请求签名验证失败，请使用新的签名方法 `TC3-HMAC-SHA256`。
            
            当您看到此类错误信息，说明此次请求签名计算错误，强烈建议使用官网提供的 SDK 调用，自己计算签名比较容易出错，SDK 屏蔽了计算签名的细节，调用者只需关注接口参数。
            如果仍然想自己计算签名，参照官网签名文档，可以在API Explorer【签名串生成】处进行签名验证。
            此外，SecretKey输入错误也可能会导致签名计算错误。
            """
        XCTAssertEqual(formatErrorSolution(solution), """
            - The provided credentials could not be validated. Please check your signature is correct.
              请求签名验证失败，请检查您的签名计算是否正确。
            - The provided credentials could not be validated because of exceeding request size limit, please use new signature method `TC3-HMAC-SHA256`.
              由于请求包大小超过限制，请求签名验证失败，请使用新的签名方法 `TC3-HMAC-SHA256`。
            
            当您看到此类错误信息，说明此次请求签名计算错误，强烈建议使用官网提供的 SDK 调用，自己计算签名比较容易出错，SDK 屏蔽了计算签名的细节，调用者只需关注接口参数。
            如果仍然想自己计算签名，参照官网签名文档，可以在API Explorer【签名串生成】处进行签名验证。
            此外，SecretKey输入错误也可能会导致签名计算错误。
            """)
    }
}
