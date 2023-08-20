enum Pagination {
    /// Offset-based pagination.
    ///
    /// The associated value is offset field for input and optional limit field for output.
    case offset(input: APIObject.Field, output: APIObject.Field? = nil)

    /// Page-based pagination.
    ///
    /// The associated value is page number field for input.
    case paged(input: APIObject.Field)

    /// Token-based pagination.
    ///
    /// The associated value is token field for both input and output.
    case token(input: APIObject.Field, output: APIObject.Field)
}

func getItemsField(for output: APIObject) -> APIObject.Field? {
    output.getFieldExactly { $0.type == .list }
}

func getTotalCountField(for output: APIObject, associative: Bool = false) -> APIObject.Field? {
    // Output contains a total count field.
    if let field = output.getFieldExactly(predicate: { ["TotalCount", "TotalCnt", "TotalNum", "TotalElements", "Total"].contains($0.name) && $0.type == .int }) {
        return field
    }
    // Output contains a single integer field, which we assume to be total count.
    if let field = output.getFieldExactly(predicate: { $0.type == .int }),
       case let name = field.metadata.name,
       name == "Count" || name.hasPrefix("Total") || name.hasSuffix("Num")
    {
        return field
    }
    // Associative queries based on the list name.
    if associative {
        // Possible suffices for the queried list name.
        let listSuffices = ["Set", "Info", "Infos", "List", "s"]
        // Possible suffices for the total count field naem.
        let countSuffices = ["Count", "Cnt", "IdNum", "Num", "TotalCount"]
        // Get entity name by removing the suffix from list, and try to locate related count field.
        if let list = getItemsField(for: output) {
            var name = list.metadata.name
            for suffix in listSuffices where name.hasSuffix(suffix) {
                name.removeLast(suffix.count)
                break
            }
            if let count = output.getFieldExactly(predicate: { $0.type == .int && countSuffices.map({ name + $0 }).contains($0.name) }) {
                return count
            }
        }
        // Associative query into the metadata object.
        if let field = output.getFieldExactly(predicate: { $0.type != .list }), field.metadata.type == .object {
            if let model = ServiceContext.objects[field.metadata.member],
               let count = getTotalCountField(for: model, associative: false)
            {
                return ("\(field.key).\(count.key)", count.metadata)
            }
        }
    }
    // Cannot find total count field at the moment.
    return nil
}

func computePaginationKind(input: APIObject, output: APIObject, service: APIModel, action: APIModel.Action) -> Pagination? {
    // The output should contain exactly 1 list.
    guard let list = getItemsField(for: output) else {
        return nil
    }
    // Offset-based pagination marked by "Offset".
    if let offset = input.getFieldExactly(predicate: { $0.name == "Offset" && $0.type == .int }) {
        // Output contains "Limit" and "Offset" fields which can be used in pagination.
        if let _ = output.getFieldExactly(predicate: { $0.name == "Offset" && $0.type == .int }),
           let limit = output.getFieldExactly(predicate: { $0.name == "Limit" && $0.type == .int })
        {
            return .offset(input: offset, output: limit)
        }
        // Output contains "TotalCount" field.
        if let _ = getTotalCountField(for: output, associative: true) {
            return .offset(input: offset)
        }
        // Output contains no other field than the item list.
        if let _ = output.getFieldExactly(predicate: { _ in true }) {
            return .offset(input: offset)
        }
        // The item list is named "Items" and contains a list of "Item"s.
        if list.metadata.name == "Items" && list.metadata.member.hasSuffix("Item") {
            return .offset(input: offset)
        }
        // Output only contains a list and a object holding query metadata.
        if let field = output.getFieldExactly(predicate: { $0.type != .list }), field.metadata.type == .object {
            return .offset(input: offset)
        }
        // Output contains a "Total" field in non-integer which we cannot make use of at the point.
        if let _ = output.getFieldExactly(predicate: { $0.name == "Total" }) {
            return .offset(input: offset)
        }
        // All other situations are regarded as illegal for pagination.
        return nil
    }
    // Token-based pagination marked by common "Token" or "Cursor" fields.
    if let token = input.getFieldExactly(predicate: { $0.name.hasSuffix("Token") || $0.name.hasSuffix("Cursor") }) {
        // Output must contain an associated token field named like "[Next]Token" or "[Next]Cursor".
        if let outputToken = output.getFieldExactly(predicate: { $0.name == token.metadata.name || $0.name == "Next\(token.metadata.name)" }) {
            // Token fields should share the same type.
            precondition(token.metadata.type == outputToken.metadata.type && token.metadata.member == outputToken.metadata.member)
            return .token(input: token, output: outputToken)
        }
    }
    // Page-based pagination marked by "PageSize".
    if let _ = input.getFieldExactly(predicate: { $0.name == "PageSize" }) {
        // Try to find a page number field which is incremented 1 by a time.
        if let field = input.getFieldExactly(predicate: { ["PageNo", "PageNum", "PageNumber", "PageId", "PageIndex"].contains($0.name) && $0.type == .int }) {
            return .paged(input: field)
        }
    }
    return nil
}

func nonOptionalIntegerValue(for field: APIObject.Field, prefix: String = "") -> String {
    precondition(field.metadata.type == .int)
    let key = removingOptionalAccess(from: field.key)
    if field.metadata.optional {
        return "(\(prefix)\(key) ?? 0)"
    } else {
        return "\(prefix)\(key)"
    }
}

extension APIObject {
    typealias Field = (key: String, metadata: APIObject.Member)

    func getFieldExactly(excludingDisabled: Bool = true, predicate: (APIObject.Member) throws -> Bool) rethrows -> Field? {
        // If there's only one object in the model, we see it as the root of output.
        let (members, prefix): (_, String?) = {
            var members = self.members
            members.removeAll(where: { $0.name == "RequestId" })
            if members.count == 1, members[0].type == .object, let model = ServiceContext.objects[members[0].member] {
                return (model.members, "\(members[0].memberIdentifier)\(members[0].optional ? "?" : "")")
            } else {
                return (members, nil)
            }
        }()
        // Check if the matched field is the only one.
        let filtered = try members.filter(predicate).filter({ !(excludingDisabled && $0.disabled) })
        guard filtered.count == 1, let field = filtered.first else {
            return nil
        }
        let member = "\(field.memberIdentifier)\(field.optional ? "?" : "")"
        // If the result is nested, add the prefix accordingly.
        if let prefix {
            return ("\(prefix).\(member)", field)
        } else {
            return (member, field)
        }
    }
}

extension APIObject {
    var totalCountType: String {
        if let count = getTotalCountField(for: self, associative: true) {
            return getSwiftType(for: count.metadata, forceOptional: true)
        } else {
            return "Never?"
        }
    }

    var itemType: String? {
        guard let items = getItemsField(for: self) else {
            return nil
        }
        return getSwiftMemberType(for: items.metadata)
    }
}
