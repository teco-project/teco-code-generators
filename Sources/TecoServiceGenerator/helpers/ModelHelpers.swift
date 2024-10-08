#if compiler(>=6.0)
private import SwiftSyntax
private import SwiftSyntaxBuilder
#else
import SwiftSyntax
import SwiftSyntaxBuilder
#endif

func getSwiftType(for model: APIObject.Member, isInitializer: Bool = false, forceOptional: Bool = false) -> String {
    var type = getSwiftMemberType(for: model)

    if case .list = model.type {
        type = "[\(type)]"
    }

    if model.optional || forceOptional {
        if !forceOptional, isInitializer, model.required && model.outputRequired {
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

func publicLetWithWrapper(for member: APIObject.Member, documentation: String = "", computed: Bool = false, deprecated: Bool = false) -> String {
    var documentation = documentation
    if documentation.last?.isNewline == false {
        documentation += "\n"
    }
    let availablility = deprecated ? "@available(*, deprecated)\n" : ""

    if let dateType = member.dateType {
        precondition(computed == false, "Computed date properties are not supported yet.")
        if !documentation.isEmpty {
            documentation += "///\n"
        }
        return """
            \(documentation)/// While the wrapped date value is immutable just like other fields, you can customize the underlying
            /// string value (through `$\(member.identifier)`) in case the synthesized encoding is incorrect.
            \(availablility)@\(dateType.propertyWrapper) public var
            """
    } else {
        return "\(documentation)\(availablility)public \(computed ? "var" : "let")"
    }
}

func deprecationMessage(for members: [String], in object: String? = nil) -> String? {
    let deprecated = {
        if let object {
            return "deprecated in '\(object)'"
        } else {
            return "deprecated"
        }
    }()

    guard members.count > 1 else {
        if members.count == 1 {
            return "'\(members[0])' is \(deprecated). Setting this parameter has no effect."
        }
        return nil
    }

    var list = members.map({ "'\($0)'" })
    let last = list.removeLast()
    return "\(list.joined(separator: ", ")) and \(last) are \(deprecated). Setting these parameters has no effect."
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
    var discardable: Bool {
        type == .object && members.count == 1
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

    var memberIdentifier: String {
        self.identifier.swiftMemberEscaped()
    }
}
