import SwiftSyntax

public func buildPartialEquatableDecl(_ qualifiedTypeName: String, key: String) -> ExtensionDeclSyntax {
    ExtensionDeclSyntax("extension \(qualifiedTypeName): Equatable") {
        FunctionDeclSyntax("""
        public static func == (lhs: \(raw: qualifiedTypeName), rhs: \(raw: qualifiedTypeName)) -> Bool {
            lhs.\(raw: key) == rhs.\(raw: key)
        }
        """)
    }
}
