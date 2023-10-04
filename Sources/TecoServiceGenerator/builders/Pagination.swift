import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections
@_implementationOnly import RegexBuilder

func buildGetItemsDecl(with field: APIObject.Field) -> DeclSyntax {
    let memberType = getSwiftMemberType(for: field.metadata)
    return DeclSyntax("""
        /// Extract the returned ``\(raw: memberType)`` list from the paginated response.
        public func getItems() -> [\(raw: memberType)] {
            self.\(raw: removingOptionalAccess(from: field.key))\(raw: field.key.contains("?") ? " ?? []" : "")
        }
        """)
}

func buildGetTotalCountDecl(with field: APIObject.Field) -> DeclSyntax {
    DeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getTotalCount() -> \(raw: getSwiftType(for: field.metadata, forceOptional: true)) {
            self.\(raw: removingOptionalAccess(from: field.key))
        }
        """)
}

func buildMakeNextRequestDecl(for pagination: Pagination, input: (name: String, metadata: APIObject), output: (name: String, metadata: APIObject)) throws -> DeclSyntax {
    try FunctionDeclSyntax("""
        /// Compute the next request based on API response.
        public func makeNextRequest(with response: \(raw: output.name)) -> \(raw: input.name)?
        """) {
        GuardStmtSyntax(conditions: buildHasMoreResultExpr(for: output.metadata, pagination: pagination)) {
            ReturnStmtSyntax(expression: NilLiteralExprSyntax())
        }
        ReturnStmtSyntax(expression: buildNextInputExpr(for: pagination, members: input.metadata.members))
    }.as(DeclSyntax.self)!
}

private func buildNextInputExpr(for pagination: Pagination, members: [APIObject.Member], prefix: String = "self") -> ExprSyntax {
    func buildInputExpr(for members: [APIObject.Member], updating keyPath: String, defaultValue: String, updatedValueBuilder: (String, String) -> String, prefix: String = "self", excludeOthers: Bool = false) -> FunctionCallExprSyntax {
        precondition(keyPath.isEmpty == false, "'keyPath' must not be empty.")
        // Regex for getting top-level member access.
        let memberAccessRegex = Regex {
            Capture {
                OneOrMore(.any, .reluctant)
            }
            "."
            Capture {
                OneOrMore(.any)
            }
        }
        // Get input member list.
        let members = members.filter({ !$0.disabled })
        var parameters = OrderedDictionary(excludeOthers ? [] : members.map({ ($0.identifier, "\(prefix).\($0.memberIdentifier)") }), uniquingKeysWith: { $1 })
        // Check if the key path is nested.
        if let match = keyPath.wholeMatch(of: memberAccessRegex) {
            let (nestedIdentifier, nestedKeyPath) = (String(match.1), String(match.2))
            let identifier = identifierFromEscaped(nestedIdentifier)
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
                parameters[identifier] = """
                    {
                        if let \(escapedIdentifier) = \(prefix).\(identifier.swiftMemberEscaped()) {
                            return \(buildInputExpr(for: object.members, updating: nestedKeyPath, defaultValue: defaultValue, updatedValueBuilder: updatedValueBuilder, prefix: escapedIdentifier).formatted())
                        } else {
                            return \(buildInputExpr(for: object.members, updating: nestedKeyPath, defaultValue: defaultValue, updatedValueBuilder: { removingParens(from: $1) }, prefix: nestedPrefix, excludeOthers: true).formatted())
                        }
                    }()
                    """
            } else {
                parameters[identifier] = buildInputExpr(for: object.members, updating: nestedKeyPath, defaultValue: defaultValue, updatedValueBuilder: updatedValueBuilder, prefix: nestedPrefix).formatted().description
            }
        } else {
            // Build and update input value field.
            parameters[identifierFromEscaped(keyPath)] = updatedValueBuilder("\(prefix).\(keyPath)", defaultValue)
        }
        // Build the initializer call syntax.
        return FunctionCallExprSyntax(callee: ExprSyntax(".init")) {
            for (label, value) in parameters {
                LabeledExprSyntax(label: label, expression: ExprSyntax("\(raw: value)"))
            }
        }
    }
    // Compute input key paths.
    let inputKeyPath: String = {
        switch pagination {
        case .token(let input, _), .offset(let input, _), .paged(let input):
            return input.key
        }
    }()
    // Compute updated value.
    let (buildUpdatedValue, defaultValue): ((String, String) -> String, String) = {
        switch pagination {
        case .token(_, let output):
            return ({ $1 }, "response.\(removingOptionalAccess(from: output.key))")
        case .offset(let input, let output):
            precondition(input.metadata.type == .int)
            let builder: (String, String) -> String = {
                "\(nonOptionalValue(for: $0, default: "0")) + \($1)"
            }
            if let output {
                precondition(output.metadata.type == .int)
                return (builder, nonOptionalValue(for: "response.\(output.key)", default: "0"))
            } else {
                return (builder, ".init(response.getItems().count)")
            }
        case .paged(let input):
            precondition(input.metadata.type == .int)
            return ({ "\(nonOptionalValue(for: $0, default: "0")) + \($1)" }, "1")
        }
    }()
    // Build the initializer call syntax.
    return buildInputExpr(for: members, updating: inputKeyPath, defaultValue: defaultValue, updatedValueBuilder: buildUpdatedValue).as(ExprSyntax.self)!
}

private func buildHasMoreResultExpr(for output: APIObject, pagination: Pagination) -> ConditionElementListSyntax {
    // See if there's indicator for more result.
    if let (key, metadata) = output.getFieldExactly(predicate: { $0.name.hasPrefix("HasNext") }) {
        precondition(metadata.optional == false && metadata.type == .bool)
        return [.init(condition: .expression("response.\(raw: key)"))]
    }
    if let (key, metadata) = output.getFieldExactly(predicate: { $0.name == "HasMore" }) {
        precondition(metadata.type == .int)
        return [.init(condition: .expression("response.\(raw: removingOptionalAccess(from: key)) == 1"))]
    }
    if let (key, metadata) = output.getFieldExactly(predicate: { $0.name == "HaveMore" }) {
        precondition(metadata.optional == false)
        switch metadata.type {
        case .int:
            return [.init(condition: .expression("response.\(raw: key) > 0"))]
        case .bool:
            return [.init(condition: .expression("response.\(raw: key)"))]
        default:
            fatalError("Unsupported type '\(getSwiftType(for: metadata))' for key 'HaveMore'")
        }
    }
    // See if there's token fot the next page.
    if case .token(_, let output) = pagination, output.metadata.nullable {
        return [.init(condition: .expression("response.\(raw: removingOptionalAccess(from: output.key)) != nil"))]
    }
    // If there's no indicator, judge by list empty.
    return [.init(condition: .expression("!response.getItems().isEmpty"))]
}
