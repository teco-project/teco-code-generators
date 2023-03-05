import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildGetItemsDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getItems() -> [\(raw: field.metadata.member)] {
            self.\(raw: field.key)\(raw: field.metadata.nullable ? " ?? []" : "")
        }
        """)
}

func buildGetTotalCountDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    return FunctionDeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getTotalCount() -> \(raw: getSwiftType(for: field.metadata, forceOptional: true)) {
            self.\(raw: field.key)
        }
        """)
}

func buildGetNextPaginatedRequestDecl(for request: String, response: String, kind: PaginationKind, input: APIObject, output: APIObject) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        /// Compute the next request based on API response.
        public func getNextPaginatedRequest(with response: \(response)) -> \(request)?
        """) {
        GuardStmtSyntax("guard \(buildHasMoreResultExpr(for: output, paginationKind: kind)) else") {
            ReturnStmtSyntax("return nil")
        }
        ReturnStmtSyntax("return \(buildNextInputExpr(for: request, members: input.members, kind: kind))")
    }
}

private func buildNextInputExpr(for type: String, members: [APIObject.Member], kind: PaginationKind) -> ExprSyntax {
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
    return .init(FunctionCallExprSyntax("\(raw: type)(\(raw: parameters.map({ "\($0.key): \($0.value)" }).joined(separator: ", ")))"))
}

private func buildHasMoreResultExpr(for output: APIObject, paginationKind: PaginationKind) -> ExprSyntax {
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
    if case .token(_, let output) = paginationKind, output.metadata.nullable {
        return ExprSyntax("response.\(raw: output.key) != nil")
    }
    // If there's no indicator, judge by list empty.
    return ExprSyntax("!response.getItems().isEmpty")
}
