import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

func buildCommonErrorStructDecl(from errors: [CommonError]) -> StructDeclSyntax {
    StructDeclSyntax("""
        /// Common error type returned by Tencent Cloud.
        public struct TCCommonError: TCServiceErrorType
        """) {
        EnumDeclSyntax("enum Code: String") {
            for error in errors {
                EnumCaseDeclSyntax("case \(raw: error.identifier) = \(literal: error.code)")
            }
        }

        VariableDeclSyntax("private let error: Code")
        VariableDeclSyntax("public let context: TCErrorContext?")
        VariableDeclSyntax("""
            public var errorCode: String {
                self.error.rawValue
            }
            """)

        InitializerDeclSyntax("""
            public init?(errorCode: String, context: TCErrorContext) {
                guard let error = Code(rawValue: errorCode) else {
                    return nil
                }
                self.error = error
                self.context = context
            }
            """)

        FunctionDeclSyntax("""
            public func asCommonError() -> TCCommonError? {
                return self
            }
            """)

        InitializerDeclSyntax("""
            internal init(_ error: Code, context: TCErrorContext? = nil) {
                self.error = error
                self.context = context
            }
            """)

        for error in errors {
            VariableDeclSyntax("""
                \(raw: buildDocumentation(summary: error.description, discussion: error.solution))
                public static var \(raw: error.identifier): TCCommonError {
                    TCCommonError(.\(raw: error.identifier))
                }
                """)
        }
    }
}
