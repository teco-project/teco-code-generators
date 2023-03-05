enum PaginationKind {
    // The associated value is token field for both input and output.
    case token(input: APIObject.Field, output: APIObject.Field)

    // The associated value is offset field for input and optional limit field for output.
    case offset(input: APIObject.Field, output: APIObject.Field? = nil)

    // The associated value is page id field for input.
    case paged(input: APIObject.Field)
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
                return ("\(field.key)\(field.metadata.optional ? "?" : "").\(count.key)", count.metadata)
            }
        }
    }
    // Else...
    return nil
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

func nonOptionalIntegerValue(for field: APIObject.Field, prefix: String = "") -> String {
    precondition(field.metadata.type == .int)
    if field.metadata.optional {
        return "(\(prefix)\(field.key) ?? 0)"
    } else {
        return "\(prefix)\(field.key)"
    }
}

extension APIObject {
    typealias Field = (key: String, metadata: APIObject.Member)

    func getFieldExactly(_ match: (APIObject.Member) throws -> Bool) rethrows -> Field? {
        let (members, namespace): (_, String?) = {
            var members = self.members
            members.removeAll(where: { $0.name == "RequestId" })
            if members.count == 1, members[0].type == .object, let model = ServiceContext.objects[members[0].member] {
                return (model.members, "\(members[0].identifier)\(members[0].optional ? "?" : "")")
            } else {
                return (members, nil)
            }
        }()

        let filtered = try members.filter(match)
        guard filtered.count == 1, let field = filtered.first else {
            return nil
        }
        if let namespace {
            return ("\(namespace).\(field.identifier)", field)
        } else {
            return (field.escapedIdentifier, field)
        }
    }
}
