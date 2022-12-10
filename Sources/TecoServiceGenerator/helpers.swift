import ArgumentParser
@_implementationOnly import OrderedCollections

func getErrorDomain(from code: String) -> String? {
    let components = code.split(separator: ".")
    guard components.count >= 2 else {
        return nil
    }
    precondition(components.count == 2)
    return .init(components[0])
}

func getErrorDomains(from errors: [APIError]) -> [String] {
    let domains = OrderedSet(errors.map(\.code).compactMap(getErrorDomain))
    return domains.sorted()
}

func generateErrorMap(from errors: [APIError]) -> OrderedDictionary<String, APIError> {
    var errorMap: OrderedDictionary<String, APIError> = [:]

    for error in errors {
        errorMap[error.identifier] = error
    }
    errorMap.sort()

    return errorMap
}

func generateDomainedErrorMap(from errors: [APIError], for domain: String) -> OrderedDictionary<String, APIError> {
    let errors = errors.filter { $0.code.hasPrefix(domain) }
    var errorMap: OrderedDictionary<String, APIError> = [:]
    
    for error in errors {
        if let identifier = error.identifier(for: domain) {
            errorMap[identifier] = error
        }
    }
    errorMap.sort()
    
    if let otherError = errorMap["other"] {
        errorMap.removeValue(forKey: "other")
        errorMap.updateValue(otherError, forKey: "other")
    }
    
    return errorMap
}

func getSwiftType(for model: APIObject.Member, usage: APIObject.Usage? = nil) -> String {
    if case .object = model.type {
        return model.member
    }

    switch model.type {
    case .bool:
        assert(model.member == "bool")
    case .int:
        assert(model.member.contains("int"))
    case .float:
        assert(model.member == "float" || model.member == "double")
    case .string:
        assert(model.member == "string" || model.member.contains("date") || model.member.contains("time"))
    default:
        break
    }

    var type = model.member

    if type.contains("date") || type.contains("time") {
        type = "Date"
    } else {
        type = type.replacingOccurrences(of: "int", with: "Int").upperFirst()
    }

    if case .list = model.type {
        type = "[\(type)]"
    }

    if !model.required || model.nullable {
        if model.required && model.nullable, usage == .in || usage == .both {
            assertionFailure("Required optional field is unimplemented!")
        }
        type += "?"
    }
 
    return type
}

func docComment(_ document: String?) -> String {
    (document ?? "")
        .split(whereSeparator: \.isNewline)
        .map { "/// \($0)" }
        .joined(separator: "\n")
}

func dateFixme(_ member: APIObject.Member) -> String {
    return getSwiftType(for: member) == "Date" ? "// FIXME: Codable support not implemented for \(member.member) yet.\n" : ""
}

extension APIObject {
    var protocols: [String] {
        guard let usage = self.usage else {
            fatalError("Unexpectedly found invalid usage.")
        }

        switch usage {
        case .in:
            return ["TCInputModel"]
        case .out:
            return ["TCOutputModel"]
        case .both:
            return ["TCInputModel", "TCOutputModel"]
        }
    }
}
