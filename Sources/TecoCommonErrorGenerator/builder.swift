#if compiler(>=6.0)
internal import SwiftSyntax
private import SwiftSyntaxBuilder
private import TecoCodeGeneratorCommons
#else
import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons
#endif

func buildCommonErrorStructDecl(from errors: [CommonError]) throws -> some DeclSyntaxProtocol {
    try StructDeclSyntax("""
        /// Common error type returned by Tencent Cloud.
        public struct TCCommonError: TCServiceErrorType
        """) {
        try EnumDeclSyntax("enum Code: String") {
            for error in errors {
                DeclSyntax("case \(raw: error.identifier) = \(literal: error.code)")
            }
        }

        DeclSyntax("private let error: Code")
        DeclSyntax("public let context: TCErrorContext?")
        DeclSyntax("""
            public var errorCode: String {
                self.error.rawValue
            }
            """)

        DeclSyntax("""
            public init?(errorCode: String, context: TCErrorContext) {
                guard let error = Code(rawValue: errorCode) else {
                    return nil
                }
                self.error = error
                self.context = context
            }
            """)

        DeclSyntax("""
            public func asCommonError() -> TCCommonError? {
                return self
            }
            """)

        DeclSyntax("""
            internal init(_ error: Code, context: TCErrorContext? = nil) {
                self.error = error
                self.context = context
            }
            """)

        for error in errors {
            DeclSyntax("""
                \(raw: buildDocumentation(summary: error.description, discussion: error.solution))
                public static var \(raw: error.identifier): TCCommonError {
                    TCCommonError(.\(raw: error.identifier))
                }
                """)
        }
    }
}
