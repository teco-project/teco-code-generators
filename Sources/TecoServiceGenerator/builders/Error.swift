import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons
#if compiler(>=6.0)
internal import OrderedCollections
#else
@_implementationOnly import OrderedCollections
#endif

func buildServiceErrorTypeDecl(_ serviceName: String) throws -> some DeclSyntaxProtocol {
    let serviceError = "TC\(serviceName)Error"
    return try ProtocolDeclSyntax("""
        /// Service error type returned by `\(raw: serviceName)`.
        public protocol \(raw: serviceError)Type: TCServiceErrorType
        """) {
        DeclSyntax("""
            /// Get the service error as ``\(raw: serviceError)``.
            ///
            /// - Returns: ``\(raw: serviceError)`` that holds the same error code and context.
            func \(raw: "as\(serviceName)Error")() -> \(raw: serviceError)
            """)
    }
}

func buildErrorStructDecl(_ qualifiedTypeName: String, domains: [String] = [], errorMap: OrderedDictionary<String, APIError>, serviceName: String) throws -> some DeclSyntaxProtocol {
    let serviceError = "TC\(serviceName)Error"
    return try StructDeclSyntax("public struct \(raw: qualifiedTypeName): \(raw: serviceError)Type") {
        try EnumDeclSyntax("enum Code: String") {
            for (identifier, error) in errorMap {
                DeclSyntax("case \(raw: identifier.swiftIdentifierEscaped()) = \(literal: error.code)")
            }
        }

        if !domains.isEmpty {
            DeclSyntax("""
                /// Error domains affliated to ``\(raw: qualifiedTypeName)``.
                public static var domains: [TCErrorType.Type] {
                    [\(raw: domains.map { "\($0).self" }.joined(separator: ", "))]
                }
                """)
        }

        DeclSyntax("private let error: Code")
        DeclSyntax("public let context: TCErrorContext?")
        DeclSyntax("""
            public var errorCode: String {
                self.error.rawValue
            }
            """)

        DeclSyntax("""
            /// Initializer used by ``TCClient`` to match an error of this type.
            public init?(errorCode: String, context: TCErrorContext) {
                guard let error = Code(rawValue: errorCode) else {
                    return nil
                }
                self.error = error
                self.context = context
            }
            """)

        DeclSyntax("""
            internal init(_ error: Code, context: TCErrorContext? = nil) {
                self.error = error
                self.context = context
            }
            """)

        for (identifier, error) in errorMap {
            DeclSyntax("""
                \(raw: buildDocumentation(summary: error.description, discussion: error.solution))
                public static var \(raw: identifier.swiftIdentifierEscaped()): \(raw: qualifiedTypeName) {
                    \(raw: qualifiedTypeName)(.\(raw: identifier))
                }
                """)
        }

        // Service error protocol stub
        try FunctionDeclSyntax("public func as\(raw: serviceName)Error() -> \(raw: serviceError)") {
            if qualifiedTypeName == serviceError {
                StmtSyntax("return self")
            } else {
                DeclSyntax("let code: \(raw: serviceError).Code")
                try SwitchExprSyntax("switch self.error") {
                    for (identifier, error) in errorMap {
                        SwitchCaseSyntax("case .\(raw: identifier): code = .\(raw: error.identifier)")
                    }
                }
                StmtSyntax("return \(raw: serviceError)(code, context: self.context)")
            }
        }
    }
}
