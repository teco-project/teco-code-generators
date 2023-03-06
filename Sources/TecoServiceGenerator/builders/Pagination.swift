import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

func buildGetItemsDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        /// Extract the returned item list from the paginated response.
        public func getItems() -> [\(raw: getSwiftMemberType(for: field.metadata))] {
            self.\(raw: field.key)\(raw: field.metadata.nullable || field.key.contains("?") ? " ?? []" : "")
        }
        """)
}

func buildGetTotalCountDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getTotalCount() -> \(raw: getSwiftType(for: field.metadata, forceOptional: true)) {
            self.\(raw: field.key)
        }
        """)
}

func buildMakeNextRequestDecl(for pagination: Pagination, input: (name: String, metadata: APIObject), output: (name: String, metadata: APIObject)) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        /// Compute the next request based on API response.
        public func makeNextRequest(with response: \(output.name)) -> \(input.name)?
        """) {
        GuardStmtSyntax("guard \(buildHasMoreResultExpr(for: output.metadata, pagination: pagination)) else") {
            ReturnStmtSyntax("return nil")
        }
        ReturnStmtSyntax("return \(buildNextInputExpr(for: input.name, members: input.metadata.members, kind: pagination))")
    }
}

private func buildNextInputExpr(for type: String, members: [APIObject.Member], kind: Pagination) -> ExprSyntax {
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
