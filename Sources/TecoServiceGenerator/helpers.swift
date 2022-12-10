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
    case .binary:
        assert(model.member == "binary")
    default:
        break
    }

    var type = model.member

    if type.contains("date") || type.contains("time") {
        type = "Date"
    } else if type == "binary" {
        type = "Data"
    } else if type.first?.isUppercase != true {
        type = type.replacingOccurrences(of: "int", with: "Int").upperFirst()
    }

    if case .list = model.type {
        type = "[\(type)]"
    }

    if !model.required || model.nullable {
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

func docComment(summary: String?, discussion: String?) -> String {
    var document: [String] = []
    if let summary, !summary.isEmpty {
        document.append("/// \(summary.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    if case let discussion = docComment(discussion), !discussion.isEmpty {
        document.append(discussion)
    }
    return OrderedSet(document).joined(separator: "\n///\n")
}

func codableFixme(_ member: APIObject.Member, usage: APIObject.Usage? = nil) -> String {
    guard member.type != .binary else {
        fatalError("Multipart APIs shouldn't be generated!")
    }
    
    var result = ""
    if getSwiftType(for: member) == "Date" {
        result += "// FIXME: Codable support not implemented for \(member.member) yet.\n"
    }
    if member.required && member.nullable, usage == .in || usage == .both {
        result += "// FIXME: Required optional field is not supported yet.\n"
    }
    return result
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

let swiftKeywords: Set = ["associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout", "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw", "switch", "where", "while", "Any", "as", "catch", "false", "is", "nil", "rethrows", "self", "Self", "super", "throw", "throws", "true", "try"]

extension APIObject.Member {
    var identifier: String {
        self.name.lowerFirst().swiftIdentifier
    }
}

extension String {
    var swiftIdentifier: String {
        swiftKeywords.contains(self) ? "`\(self)`" : self
    }
}
