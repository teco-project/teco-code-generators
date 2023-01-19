import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildServiceErrorTypeDecl(_ serviceNamespace: String) -> ProtocolDeclSyntax {
    ProtocolDeclSyntax("""
        /// Service error type returned by `\(serviceNamespace)`.
        public protocol TC\(serviceNamespace)ErrorType: TCServiceErrorType
        """) {
        let baseErrorType = "TC\(serviceNamespace)Error"
        FunctionDeclSyntax("""
            /// Get the service error as ``\(raw: baseErrorType)``.
            ///
            /// - Returns: ``\(raw: baseErrorType)`` that holds the same error code and context.
            func \(raw: "as\(serviceNamespace)Error")() -> \(raw: baseErrorType)
            """)
    }
}

func buildErrorStructDecl(_ qualifiedTypeName: String, domains: [String] = [], errorMap: OrderedDictionary<String, APIError>, baseErrorShortname: String) -> StructDeclSyntax {
    StructDeclSyntax("public struct \(qualifiedTypeName): TC\(baseErrorShortname)Type") {
        EnumDeclSyntax("enum Code: String") {
            for (identifier, error) in errorMap {
                EnumCaseDeclSyntax("case \(raw: identifier.swiftIdentifierEscaped()) = \(literal: error.code)")
            }
        }
        
        if !domains.isEmpty {
            VariableDeclSyntax("""
                /// Error domains affliated to ``\(raw: qualifiedTypeName)``.
                public static var domains: [TCErrorType.Type] {
                    [\(raw: domains.map { "\($0).self" }.joined(separator: ", "))]
                }
                """)
        }
        
        VariableDeclSyntax("private let error: Code")
        VariableDeclSyntax("public let context: TCErrorContext?")
        VariableDeclSyntax("""
            public var errorCode: String {
                self.error.rawValue
            }
            """)
        
        InitializerDeclSyntax("""
            /// Initializer used by ``TCClient`` to match an error of this type.
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
        
        for (identifier, error) in errorMap {
            let swiftIdentifier = identifier.swiftIdentifierEscaped()
            VariableDeclSyntax("""
                \(raw: docComment(summary: error.description, discussion: error.solution))
                public static var \(raw: swiftIdentifier): \(raw: qualifiedTypeName) {
                    \(raw: qualifiedTypeName)(.\(raw: swiftIdentifier))
                }
                """)
        }

        // Service error protocol stub
        let baseErrorType = "TC\(baseErrorShortname)"
        FunctionDeclSyntax("public func as\(baseErrorShortname)() -> \(baseErrorType)") {
            if qualifiedTypeName == "TC\(baseErrorShortname)" {
                ReturnStmtSyntax("return self")
            } else {
                VariableDeclSyntax("let code: \(raw: baseErrorType).Code")
                SwitchStmtSyntax(expression: ExprSyntax("self.error")) {
                    for (identifier, error) in errorMap {
                        SwitchCaseSyntax("""
                            case .\(raw: identifier.swiftIdentifierEscaped()):
                                code = .\(raw: error.identifier)
                            """)
                    }
                }
                ReturnStmtSyntax("return \(raw: baseErrorType)(code, context: self.context)")
            }
        }
    }
}
