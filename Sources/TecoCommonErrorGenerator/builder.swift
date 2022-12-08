import SwiftSyntaxBuilder

func buildErrorStructDecl(_ qualifiedTypeName: String, errors: [ErrorDefinition]) -> StructDecl {
    StructDecl("public struct \(qualifiedTypeName): TCErrorType") {
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

func buildErrorCustomStringConvertibleDecl(_ qualifiedTypeName: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedTypeName): CustomStringConvertible") {
        VariableDecl(#"""
        public var description: String {
            return "\(self.error.rawValue): \(message ?? "")"
        }
        """#)
    }
}

func buildBaseErrorConversionDecl(_ qualifiedName: String, baseErrorType: String, baseErrorShortname: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedName)") {
        FunctionDecl("""
            public func to\(raw: baseErrorShortname)() -> \(raw: baseErrorType) {
                guard let code = \(raw: baseErrorType).Code(rawValue: self.error.rawValue) else {
                    fatalError(\(literal: """
                        Unexpected internal conversion error!
                        Please file a bug at https://github.com/teco-project/teco to help address the problem.
                        """))
                }
                return \(raw: baseErrorType)(code, context: self.context)
            }
            """)
    }
}

func buildErrorDomainListDecl(_ qualifiedTypeName: String, domains: [ErrorCode]) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedTypeName)") {
        VariableDecl("""
        public static var domains: [TCErrorType.Type] {
            return [\(raw: domains.map { "\($0).self" }.joined(separator: ", "))]
        }
        """)
    }
}
