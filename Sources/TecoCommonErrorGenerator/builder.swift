import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

func buildCommonErrorStructDecl(_ qualifiedTypeName: String, errors: [ErrorDefinition]) -> StructDeclSyntax {
    StructDeclSyntax("""
        /// Common error type returned by Tencent Cloud.
        public struct \(qualifiedTypeName): TCServiceErrorType
        """) {
        EnumDeclSyntax("enum Code: String") {
            for (code, identifier, _, _) in errors {
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

        for (_, identifier, description, solution) in errors {
            let summary = description.joined(separator: "\n")
            let solution = solution.map(formatErrorSolution)

            VariableDeclSyntax("""
                \(raw: buildDocumentation(summary: summary, discussion: solution))
                public static var \(raw: identifier): \(raw: qualifiedTypeName) {
                    \(raw: qualifiedTypeName)(.\(raw: identifier))
                }
                """)
        }
    }
}
