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

func getSwiftType(for model: APIObject.Member, isInitializer: Bool = false) -> String {
    switch model.type {
    case .bool:
        precondition(model.member == "bool")
    case .int:
        precondition(model.member.contains("int"))
    case .float:
        precondition(model.member == "float" || model.member == "double")
    case .string:
        precondition(model.member == "string" || model.dateType != nil)
    case .binary:
        precondition(model.member == "binary")
    case .object:
        precondition(model.member.first?.isUppercase ?? false)
    default:
        break
    }

    var type = model.member

    if let _ = model.dateType {
        type = "Date"
    } else if type == "binary" {
        precondition(model.type == .binary)
        type = "Data"
    } else if type.first?.isUppercase != true {
        type = type.replacingOccurrences(of: "int", with: "Int").upperFirst()
    }

    if case .list = model.type {
        type = "[\(type)]"
    }

    if model.optional {
        if isInitializer, model.required {
            // We regard required nullable fields as **required** for input and **nullable** in output,
            // so use non-optional for initializer.
            return type
        }
        type += "?"
    }
    return type
}

func skipAuthorizationParameter(for action: String) -> String {
    // Special rule for sts:AssumeRoleWithSAML & sts:AssumeRoleWithWebIdentity
    return action.hasPrefix("AssumeRoleWith") ? ", skipAuthorization: true" : ""
}

func initializerParameterList(for members: [APIObject.Member], packed: Bool = false) -> String {
    let params = members.map { member in
        let type = getSwiftType(for: member, isInitializer: true)
        var parameter = "\(member.identifier): \(type)"
        if let defaultValue = member.default, member.required {
            if type == "String" {
                parameter += " = \(defaultValue.makeLiteralSyntax())"
            } else if type == "Bool" {
                parameter += " = \(defaultValue.lowercased())"
            } else if type == "Float" || type == "Double" || type.hasPrefix("Int") || type.hasPrefix("UInt") {
                parameter += " = \(defaultValue)"
            } else if type == "Date" {
                print("FIXME: Default value support for Date not implemented yet!")
            }
        } else if !member.required {
            parameter += " = nil"
        }
        return parameter
    }

    return packed ? params.map({ $0 + ", " }).joined() : params.joined(separator: ", ")
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

func publicLetWithWrapper(for member: APIObject.Member) -> String {
    guard member.type != .binary else {
        fatalError("Multipart APIs shouldn't be generated!")
    }

    if let dateType = member.dateType {
        return """
            ///
            /// **Important:** This has to be a `var` due to a property wrapper restriction, which is about to be removed in the future.
            /// For discussions, see [Allow Property Wrappers on Let Declarations](https://forums.swift.org/t/pitch-allow-property-wrappers-on-let-declarations/61750).
            ///
            /// Although mutating this property is possible for now, it may become a `let` variable at any time. Please don't rely on such behavior.
            @\(dateType.propertyWrapper) public var
            """
    } else {
        return "public let"
    }
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

extension APIObject.Member {
    var dateType: DateType? {
        if self.type == .string, let type = DateType(rawValue: self.member) {
            return type
        }
        return nil
    }

    enum DateType: String {
        case date
        case datetime
        case datetime_iso

        var propertyWrapper: String {
            switch self {
            case .date:
                return "TCDateEncoding"
            case .datetime:
                return "TCTimestampEncoding"
            case .datetime_iso:
                return "TCTimestampISO8601Encoding"
            }
        }
    }
}

let swiftKeywords: Set = ["associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout", "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw", "switch", "where", "while", "Any", "as", "catch", "false", "is", "nil", "rethrows", "self", "Self", "super", "throw", "throws", "true", "try"]

extension APIObject.Member {
    var identifier: String {
        self.name.lowerFirst()
    }

    var escapedIdentifier: String {
        self.identifier.swiftIdentifierEscaped()
    }
}

extension String {
    func swiftIdentifierEscaped() -> String {
        swiftKeywords.contains(self) ? "`\(self)`" : self
    }
}
