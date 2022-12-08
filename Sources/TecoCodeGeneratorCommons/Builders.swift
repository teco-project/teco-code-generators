public func buildPartialEquatableDecl(_ qualifiedTypeName: String, key: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedTypeName): Equatable") {
        FunctionDecl("""
        public static func == (lhs: \(raw: qualifiedTypeName), rhs: \(raw: qualifiedTypeName)) -> Bool {
            lhs.\(raw: key) == rhs.\(raw: key)
        }
        """)
    }
}
