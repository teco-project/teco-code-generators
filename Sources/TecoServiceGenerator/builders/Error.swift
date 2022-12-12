import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildServiceErrorTypeDecl(_ serviceNamespace: String) -> ProtocolDecl {
    ProtocolDecl("""
        /// Service error type returned by `\(serviceNamespace)`.
        public protocol TC\(serviceNamespace)ErrorType: TCPlatformErrorType
        """) {
        let baseErrorType = "TC\(serviceNamespace)Error"
        FunctionDecl("""
            /// Get the service error as ``\(raw: baseErrorType)``.
            ///
            /// - Returns: ``\(raw: baseErrorType)`` that holds the same error code and context.
            func \(raw: "as\(serviceNamespace)Error")() -> \(raw: baseErrorType)
            """)
    }
}

func buildErrorStructDecl(_ qualifiedTypeName: String, domains: [String] = [], errorMap: OrderedDictionary<String, APIError>, baseErrorShortname: String) -> StructDecl {
    StructDecl("public struct \(qualifiedTypeName): TC\(baseErrorShortname)Type") {
        EnumDecl("enum Code: String") {
            for (identifier, error) in errorMap {
                EnumCaseDecl("case \(raw: identifier.swiftIdentifier) = \(literal: error.code)")
            }
        }
        
        if !domains.isEmpty {
            VariableDecl("""
                /// Error domains affliated to ``\(raw: qualifiedTypeName)``.
                public static var domains: [TCErrorType.Type] {
                    [\(raw: domains.map { "\($0).self" }.joined(separator: ", "))]
                }
                """)
        }
        
        VariableDecl("private let error: Code")
        VariableDecl("public let context: TCErrorContext?")
        VariableDecl("""
            public var errorCode: String {
                self.error.rawValue
            }
            """)
        
        InitializerDecl("""
            /// Initializer used by ``TCClient`` to match an error of this type.
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
        
        for (identifier, error) in errorMap {
            let swiftIdentifier = identifier.swiftIdentifier
            VariableDecl("""
                \(raw: docComment(summary: error.description, discussion: error.solution))
                public static var \(raw: swiftIdentifier): \(raw: qualifiedTypeName) {
                    \(raw: qualifiedTypeName)(.\(raw: swiftIdentifier))
                }
                """)
        }

        // Service error protocol stub
        let baseErrorType = "TC\(baseErrorShortname)"
        FunctionDecl("public func as\(baseErrorShortname)() -> \(baseErrorType)") {
            if qualifiedTypeName == "TC\(baseErrorShortname)" {
                ReturnStmt("return self")
            } else {
                VariableDecl("let code: \(raw: baseErrorType).Code")
                SwitchStmt(expression: Expr("self.error")) {
                    for (identifier, error) in errorMap {
                        SwitchCase("""
                            case .\(raw: identifier.swiftIdentifier):
                                code = .\(raw: error.identifier)
                            """)
                    }
                }
                ReturnStmt("return \(raw: baseErrorType)(code, context: self.context)")
            }
        }
    }
}
