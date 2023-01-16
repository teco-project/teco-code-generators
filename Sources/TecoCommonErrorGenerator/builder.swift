import SwiftSyntax
import SwiftSyntaxBuilder

func buildCommonErrorStructDecl(_ qualifiedTypeName: String, errors: [ErrorDefinition]) -> StructDeclSyntax {
    StructDeclSyntax("""
        /// Common error type returned by Tencent Cloud API.
        public struct \(qualifiedTypeName): TCPlatformErrorType
        """) {
        EnumDeclSyntax("enum Code: String") {
            for (code, identifier, _) in errors {
                EnumCaseDeclSyntax("case \(raw: identifier) = \(literal: code)")
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

        InitializerDeclSyntax("""
            internal init(_ error: Code, context: TCErrorContext? = nil) {
                self.error = error
                self.context = context
            }
            """)

        for (_, identifier, description) in errors {
            let comment = description.joined(separator: " / ")
            VariableDeclSyntax("""
                \(raw: comment.isEmpty ? "" : "/// \(comment)")
                public static var \(raw: identifier): \(raw: qualifiedTypeName) {
                    \(raw: qualifiedTypeName)(.\(raw: identifier))
                }
                """)
        }
    }
}
