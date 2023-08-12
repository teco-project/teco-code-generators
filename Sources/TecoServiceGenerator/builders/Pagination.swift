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
        StmtSyntax("return \(buildNextInputExpr(for: input.name, members: input.metadata.members, kind: pagination))")
    }.as(DeclSyntax.self)!
}

private func buildNextInputExpr(for type: String, members: [APIObject.Member], kind: Pagination) -> ExprSyntax {
    let members = members.filter({ !$0.disabled })
    var parameters = OrderedDictionary(members.map({ ($0.identifier, "self.\($0.identifier)") }), uniquingKeysWith: { $1 })
    switch kind {
    case .token(let input, let output):
        parameters[input.key] = "response.\(output.key)"
    case .offset(let input, let output):
        let expr = nonOptionalIntegerValue(for: input, prefix: "self.")
        if let output {
            parameters[input.key] = "\(expr) + \(nonOptionalIntegerValue(for: output, prefix: "response."))"
        } else {
            parameters[input.key] = "\(expr) + .init(response.getItems().count)"
        }
    case .paged(let input):
        parameters[input.key] = "\(nonOptionalIntegerValue(for: input, prefix: "self.")) + 1"
    }
    return FunctionCallExprSyntax(callee: ExprSyntax("\(raw: type)")) {
        for (label, value) in parameters {
            LabeledExprSyntax(label: label, expression: ExprSyntax("\(raw: value)"))
        }
    }.as(ExprSyntax.self)!
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
