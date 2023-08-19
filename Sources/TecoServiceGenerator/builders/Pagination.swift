import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildGetItemsDecl(with field: APIObject.Field) -> DeclSyntax {
    let memberType = getSwiftMemberType(for: field.metadata)
    return DeclSyntax("""
        /// Extract the returned ``\(raw: memberType)`` list from the paginated response.
        public func getItems() -> [\(raw: memberType)] {
            self.\(raw: field.key)\(raw: field.metadata.optional || field.key.contains("?") ? " ?? []" : "")
        }
        """)
}

func buildGetTotalCountDecl(with field: APIObject.Field) -> DeclSyntax {
    DeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getTotalCount() -> \(raw: getSwiftType(for: field.metadata, forceOptional: true)) {
            self.\(raw: field.key)
        }
        """)
}

func buildMakeNextRequestDecl(for pagination: Pagination, input: (name: String, metadata: APIObject), output: (name: String, metadata: APIObject)) throws -> DeclSyntax {
    try FunctionDeclSyntax("""
        /// Compute the next request based on API response.
        public func makeNextRequest(with response: \(raw: output.name)) -> \(raw: input.name)?
        """) {
        try GuardStmtSyntax("guard \(buildHasMoreResultExpr(for: output.metadata, pagination: pagination)) else") {
            StmtSyntax("return nil")
        }
        StmtSyntax("return \(buildNextInputExpr(for: pagination, members: input.metadata.members))")
    }.as(DeclSyntax.self)!
}

private func buildNextInputExpr(for pagination: Pagination, members: [APIObject.Member], prefix: String = "self") -> ExprSyntax {
    func buildInputExpr(for members: [APIObject.Member], updating keyPath: some Collection<String>, to value: String, defaultValue: String, prefix: String = "self", excludeOthers: Bool = false) -> FunctionCallExprSyntax {
        // Key path shouldn't be empty.
        guard let nestedIdentifier = keyPath.first else {
            fatalError("'keyPath' must not be empty.")
        }
        // Get input member list.
        let members = members.filter({ !$0.disabled && $0.type != .binary })
        var parameters = OrderedDictionary(excludeOthers ? [] : members.map({ ($0.identifier, "\(prefix).\($0.memberIdentifier)") }), uniquingKeysWith: { $1 })
        let identifier = identifierFromEscaped(nestedIdentifier)
        if case let nestedKeyPath = keyPath.dropFirst(), !nestedKeyPath.isEmpty {
            // Deep into nested objects.
            guard let member = members.first(where: { $0.identifier == identifier }),
                  member.type == .object,
                  let object = ServiceContext.objects[member.member]
            else {
                fatalError("Broken nested key '\(prefix).\(nestedIdentifier)'")
            }
            let nestedPrefix = "\(prefix).\(nestedIdentifier)"
            // Handle optional cases.
            if nestedIdentifier.hasSuffix("?") {
                let escapedIdentifier = identifier.swiftIdentifierEscaped()
                let updatedValue = replacingOptionalKeyPath(nestedPrefix, in: value, with: escapedIdentifier)
                parameters[identifier] = """
                    {
                        if let \(escapedIdentifier) = \(prefix).\(identifier.swiftMemberEscaped()) {
                            return \(buildInputExpr(for: object.members, updating: nestedKeyPath, to: updatedValue, defaultValue: defaultValue, prefix: escapedIdentifier).formatted())
                        } else {
                            return \(buildInputExpr(for: object.members, updating: nestedKeyPath, to: defaultValue, defaultValue: defaultValue, prefix: nestedPrefix, excludeOthers: true).formatted())
                        }
                    }()
                    """
            } else {
                parameters[identifier] = buildInputExpr(for: object.members, updating: nestedKeyPath, to: value,  defaultValue: defaultValue, prefix: nestedPrefix).formatted().description
            }
        } else {
            // Handle unnested input normally.
            parameters[identifier] = value
        }
        // Build the initializer call syntax.
        return FunctionCallExprSyntax(callee: ExprSyntax(".init")) {
            for (label, value) in parameters {
                LabeledExprSyntax(label: label, expression: ExprSyntax("\(raw: value)"))
            }
        }
    }
    // Compute input key paths.
    let inputKeyPath: [String] = {
        switch pagination {
        case .token(let input, _), .offset(let input, _), .paged(let input):
            return input.key.split(separator: ".").map(String.init)
        }
    }()
    // Compute updated value.
    let (buildUpdatedValue, defaultValue): ((String) -> String, String) = {
        switch pagination {
        case .token(_, let output):
            return ({ $0 }, "response.\(output.key)")
        case .offset(let input, let output):
            let expr = nonOptionalIntegerValue(for: input, prefix: "self.")
            if let output {
                return ({ "\(expr) + \($0)" }, nonOptionalIntegerValue(for: output, prefix: "response."))
            } else {
                return ({ "\(expr) + \($0)" }, ".init(response.getItems().count)")
            }
        case .paged(let input):
            return ({ "\(nonOptionalIntegerValue(for: input, prefix: "self.")) + \($0)" }, "1")
        }
    }()
    // Build the initializer call syntax.
    return buildInputExpr(for: members, updating: inputKeyPath, to: buildUpdatedValue(defaultValue), defaultValue: removingParens(from: defaultValue)).as(ExprSyntax.self)!
}

private func buildHasMoreResultExpr(for output: APIObject, pagination: Pagination) -> ExprSyntax {
    // See if there's indicator for more result.
    if let (key, metadata) = output.getFieldExactly({ $0.name.hasPrefix("HasNext") }) {
        precondition(metadata.optional == false && metadata.type == .bool)
        return ExprSyntax("response.\(raw: key)")
    }
    if let (key, metadata) = output.getFieldExactly({ $0.name == "HasMore" }) {
        precondition(metadata.type == .int)
        return ExprSyntax("response.\(raw: key) == 1")
    }
    if let (key, metadata) = output.getFieldExactly({ $0.name == "HaveMore" }) {
        precondition(metadata.optional == false)
        switch metadata.type {
        case .int:
            return ExprSyntax("response.\(raw: key) > 0")
        case .bool:
            return ExprSyntax("response.\(raw: key)")
        default:
            fatalError("Unsupported type \(getSwiftType(for: metadata)) for key 'HaveMore'")
        }
    }
    // See if there's token fot the next page.
    if case .token(_, let output) = pagination, output.metadata.nullable {
        return ExprSyntax("response.\(raw: output.key) != nil")
    }
    // If there's no indicator, judge by list empty.
    return ExprSyntax("!response.getItems().isEmpty")
}
