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

func buildToCommonErrorDecl(_ qualifiedName: String, commonErrorType: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedName)") {
        FunctionDecl("""
            public func toCommonError() -> \(raw: commonErrorType)? {
                guard let code = \(raw: commonErrorType).Code(rawValue: self.error.rawValue) else {
                    return nil
                }
                return \(raw: commonErrorType)(code, context: self.context)
            }
            """)
    }
}
