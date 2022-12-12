import SwiftSyntaxBuilder

func buildCommonErrorStructDecl(_ qualifiedTypeName: String, errors: [ErrorDefinition]) -> StructDecl {
    StructDecl("""
        /// Common error type returned by Tencent Cloud API.
        public struct \(qualifiedTypeName): TCPlatformErrorType
        """) {
        EnumDecl("enum Code: String") {
            for (code, identifier, _) in errors {
                EnumCaseDecl("case \(raw: identifier) = \(literal: code)")
            }
        }

        VariableDecl("private let error: Code")
        VariableDecl("public let context: TCErrorContext?")
        VariableDecl("""
            public var errorCode: String {
                self.error.rawValue
            }
            """)

        InitializerDecl("""
            public init?(errorCode: String, context: TCErrorContext) {
                guard let error = Code(rawValue: errorCode) else {
                    return nil
                }
                self.error = error
                self.context = context
            }
            """)

        InitializerDecl("""
            internal init(_ error: Code, context: TCErrorContext? = nil) {
                self.error = error
                self.context = context
            }
            """)

        for (_, identifier, description) in errors {
            let comment = description.joined(separator: " / ")
            VariableDecl("""
                \(raw: comment.isEmpty ? "" : "/// \(comment)")
                public static var \(raw: identifier): \(raw: qualifiedTypeName) {
                    \(raw: qualifiedTypeName)(.\(raw: identifier))
                }
                """)
        }
    }
}
