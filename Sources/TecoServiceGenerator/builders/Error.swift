import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildErrorStructDecl(_ qualifiedTypeName: String, errorMap: OrderedDictionary<String, APIError>) -> StructDecl {
    StructDecl("public struct \(qualifiedTypeName): TCErrorType") {
        EnumDecl("enum Code: String") {
            for (identifier, error) in errorMap {
                EnumCaseDecl("case \(raw: identifier.swiftIdentifier) = \(literal: error.code)")
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
            /// Initializer used by ``TCClient`` to match an error of this type.
            ///
            /// You should not use this initializer directly as there are no public initializers for ``TCErrorContext``.
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

func buildBaseErrorConversionDecl(_ qualifiedName: String, baseErrorShortname: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedName)") {
        let baseErrorType = "TC\(baseErrorShortname)"
        FunctionDecl("""
            /// - Returns: ``\(raw: baseErrorType)`` that holds the same error and context.
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

func buildCommonErrorConversionDecl(_ qualifiedName: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedName)") {
        FunctionDecl("""
            /// - Returns: ``TCCommonError`` that holds the same error and context.
            public func toCommonError() -> TCCommonError? {
                if let context = self.context, let error = TCCommonError(errorCode: self.error.rawValue, context: context) {
                    return error
                }
                return nil
            }
            """)
    }
}

func buildErrorDomainListDecl(_ qualifiedTypeName: String, domains: [String]) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedTypeName)") {
        VariableDecl("""
        public static var domains: [TCErrorType.Type] {
            return [\(raw: domains.map { "\($0).self" }.joined(separator: ", "))]
        }
        """)
    }
}
