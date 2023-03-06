func getSwiftType(for model: APIObject.Member, isInitializer: Bool = false, forceOptional: Bool = false) -> String {
    var type = getSwiftMemberType(for: model)

    if case .list = model.type {
        type = "[\(type)]"
    }

    if model.optional || forceOptional {
        if !forceOptional, isInitializer, model.required {
            // We regard required nullable fields as **required** for input and **nullable** in output,
            // so use non-optional for initializer.
            return type
        }
        type += "?"
    }
    return type
}

func getSwiftMemberType(for model: APIObject.Member) -> String {
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
 
    return type
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

func publicLetWithWrapper(for member: APIObject.Member) -> String {
    guard member.type != .binary else {
        fatalError("Multipart APIs shouldn't be generated!")
    }

    if let dateType = member.dateType {
        return """
            ///
            /// While the wrapped date value is immutable just like other fields, you can customize the projected
            /// string value (through `$`-prefix) in case the synthesized encoding is incorrect.
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

extension APIObject.Member {
    var identifier: String {
        self.name.lowerFirst()
    }

    var escapedIdentifier: String {
        self.identifier.swiftIdentifierEscaped()
    }
}
