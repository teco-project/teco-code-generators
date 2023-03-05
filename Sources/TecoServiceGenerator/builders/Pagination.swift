import SwiftSyntax
import SwiftSyntaxBuilder
@_implementationOnly import OrderedCollections

enum PaginationKind {
    // The associated value is token field for both input and output.
    case token(input: APIObject.Field, output: APIObject.Field)

    // The associated value is offset field for input and optional limit field for output.
    case offset(input: APIObject.Field, output: APIObject.Field? = nil)

    // The associated value is page id field for input.
    case paged(input: APIObject.Field)
}

func buildGetItemsDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getItems() -> [\(raw: field.metadata.member)] {
            self.\(raw: field.key)\(raw: field.metadata.nullable ? " ?? []" : "")
        }
        """)
}

func getItemsField(for output: APIObject) -> APIObject.Field? {
    output.getFieldExactly({ $0.type == .list })
}

func getTotalCountField(for output: APIObject, associative: Bool = false) -> APIObject.Field? {
    // The output contains total count field.
    if let field = output.getFieldExactly({ ["TotalCount", "TotalCnt", "TotalNum", "TotalElements", "Total"].contains($0.name) && $0.type == .int }) {
        return field
    }
    // The output contains a single integer field, which we assume to be total count.
    if let field = output.getFieldExactly({ $0.type == .int }),
       case let name = field.metadata.name,
       name == "Count" || name.hasPrefix("Total") || name.hasSuffix("Num")
    {
        return field
    }
    // Associative queries based on the list name.
    if associative {
        // Associative query based on the list name.
        let listSuffices = ["Set", "Info", "Infos", "List", "s"]
        let countSuffices = ["Count", "Cnt", "IdNum", "Num", "TotalCount"]
        if let list = output.getFieldExactly({ $0.type == .list }) {
            var name = list.metadata.name
            for suffix in listSuffices where name.hasSuffix(suffix) {
                name.removeLast(suffix.count)
                break
            }
            if let count = output.getFieldExactly({ $0.type == .int && countSuffices.map({ name + $0 }).contains($0.name) }) {
                return count
            }
        }
        // Associative query into the object.
        if let field = output.getFieldExactly({ $0.type != .list }), field.metadata.type == .object {
            if let model = ServiceContext.objects[field.metadata.member],
               let count = getTotalCountField(for: model, associative: false)
            {
                return ("\(field.key).\(count.key)", count.metadata)
            }
        }
    }
    // Else...
    return nil
}

func buildGetTotalCountDecl(with field: APIObject.Field) -> FunctionDeclSyntax {
    return FunctionDeclSyntax("""
        /// Extract the total count from the paginated response.
        public func getTotalCount() -> \(raw: getSwiftType(for: field.metadata, forceOptional: true)) {
            self.\(raw: field.key)
        }
        """)
}

func getPaginationKind(input: APIObject, output: APIObject, service: APIModel, action: APIModel.Action) -> PaginationKind? {
    // The response should contain exactly 1 list.
    guard let list = output.getFieldExactly({ $0.type == .list }) else {
        return nil
    }
    if let offset = input.getFieldExactly({ $0.name == "Offset" && $0.type == .int }) {
        // Limit-Offset
        if let _ = output.getFieldExactly({ $0.name == "Limit" && $0.type == .int }),
           let offsetOut = output.getFieldExactly({ $0.name == "Offset" && $0.type == .int })
        {
            return .offset(input: offset, output: offsetOut)
        }
        // TotalCount
        if let _ = getTotalCountField(for: output, associative: true) {
            return .offset(input: offset)
        }
        // 0. 仅有一个list
        if let _ = output.getFieldExactly({ _ in true }) {
            return .offset(input: offset)
        }
        // 1. 如果list名字叫items，认为合法
        if list.metadata.name == "Items" && list.metadata.member.hasSuffix("Item") {
            return .offset(input: offset)
        }
        // 2. 如果只有list和object，认为合法
        if let field = output.getFieldExactly({ $0.type != .list }), field.metadata.type == .object {
            return .offset(input: offset)
        }
        // 3. 如果存在Total字段，认为合法
        if let _ = output.getFieldExactly({ $0.name == "Total" }) {
            return .offset(input: offset)
        }
        // 4. 其它情况认为非法
        return nil
    }
    // Token为请求和响应公共字段
    if let token = input.getFieldExactly({ $0.name.hasSuffix("Token") || $0.name.hasSuffix("Cursor") }) {
        if let outputToken = output.getFieldExactly({ $0.name == token.metadata.name || $0.name == "Next\(token.metadata.name)" }) {
            precondition(token.metadata.type == outputToken.metadata.type && token.metadata.member == outputToken.metadata.member)
            return .token(input: token, output: outputToken)
        }
    }
    // PageSize标志分页请求
    if let _ = input.getFieldExactly({ $0.name == "PageSize" }) {
        if let field = input.getFieldExactly({ ["PageNo", "PageNum", "PageNumber", "PageId", "PageIndex"].contains($0.name) && $0.type == .int }) {
            return .paged(input: field)
        }
    }
    return nil
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
        let expr = buildNonOptionalIntegerValue(for: input, prefix: "self.")
        if let output {
            parameters[input.key] = "\(expr) + \(buildNonOptionalIntegerValue(for: output, prefix: "response."))"
        } else {
            parameters[input.key] = "\(expr) + .init(response.getItems().count)"
        }
    case .paged(let input):
        parameters[input.key] = "\(buildNonOptionalIntegerValue(for: input, prefix: "self.")) + 1"
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

private func buildNonOptionalIntegerValue(for field: APIObject.Field, prefix: String = "") -> String {
    precondition(field.metadata.type == .int)
    if field.metadata.optional {
        return "(\(prefix)\(field.key) ?? 0)"
    } else {
        return "\(prefix)\(field.key)"
    }
}
