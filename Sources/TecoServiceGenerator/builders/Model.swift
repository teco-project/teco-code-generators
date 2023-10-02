import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

func buildModelMemberDeprecationAttribute(for members: [APIObject.Member], in model: String? = nil, functionNameBuilder: @escaping (String) -> String) -> AttributeSyntax? {
    guard case let deprecated = members.filter(\.disabled),
          let message = deprecationMessage(for: deprecated.map(\.identifier), in: model) else {
        return nil
    }
    let renamed = functionNameBuilder(members.filter({ !$0.disabled }).map({ "\($0.identifier):" }).joined())
    let renamedSyntax = SimpleStringLiteralExprSyntax(openingQuote: .stringQuoteToken(), segments: [.init(content: .stringSegment(renamed))], closingQuote: .stringQuoteToken())
    let messageSyntax = SimpleStringLiteralExprSyntax(openingQuote: .stringQuoteToken(), segments: [.init(content: .stringSegment(message))], closingQuote: .stringQuoteToken())
    let argumentListSyntax = AvailabilityArgumentListSyntax {
        AvailabilityArgumentSyntax(argument: .token(.binaryOperator("*")))
        AvailabilityArgumentSyntax(argument: .token(.keyword(.deprecated)))
        AvailabilityArgumentSyntax(argument: .availabilityLabeledArgument(.init(label: .keyword(.renamed), value: .string(renamedSyntax))))
        AvailabilityArgumentSyntax(argument: .availabilityLabeledArgument(.init(label: .keyword(.message), value: .string(messageSyntax))))
    }
    return AttributeSyntax(
        attributeName: TypeSyntax("available"),
        leftParen: .leftParenToken(),
        arguments: .availability(argumentListSyntax),
        rightParen: .rightParenToken()
    )
}

func buildDefaultArgument(for member: APIObject.Member) -> ExprSyntax? {
    let type = getSwiftType(for: member, isInitializer: true)
    if let defaultValue = member.default, member.required {
        if type == "String" {
            return ExprSyntax(literal: defaultValue)
        } else if type == "Bool" {
            return ExprSyntax("\(raw: defaultValue.lowercased())")
        } else if type == "Float" || type == "Double" || type.hasPrefix("Int") || type.hasPrefix("UInt") {
            return ExprSyntax("\(raw: defaultValue)")
        } else if type == "Date" {
            fatalError("Default value support for Date not implemented yet!")
        }
    }
    if !member.required || !member.outputRequired {
        return NilLiteralExprSyntax().as(ExprSyntax.self)
    }
    return nil
}

@FunctionParameterListBuilder
func buildInitializerParameterList(for members: [APIObject.Member], includeDeprecated: Bool = false) -> FunctionParameterListSyntax {
    for member in members where includeDeprecated || !member.disabled {
        FunctionParameterSyntax(
            firstName: "\(raw: member.identifier)",
            type: TypeSyntax("\(raw: getSwiftType(for: member, isInitializer: true))"),
            defaultValue: buildDefaultArgument(for: member).map { .init(value: $0) }
        )
    }
}

func buildRequestModelDecl(for input: String, metadata: APIObject, pagination: Pagination?, output: (name: String, metadata: APIObject)) throws -> StructDeclSyntax {
    let requestType = {
        if metadata.members.contains(where: { $0.type == .binary }) {
            precondition(pagination == nil, "Pagination support isn't implemented for Multipart requests.")
            return "TCMultipartRequest"
        } else if pagination != nil {
            return "TCPaginatedRequest"
        } else {
            return "TCRequest"
        }
    }()
    return try StructDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.document))
        public struct \(raw: input): \(raw: requestType)
        """) {
        let inputMembers = metadata.members.filter({ $0.type != .binary })
        buildModelMemberList(for: input, usage: .in, members: inputMembers)

        try buildModelInitializerDecls(for: input, members: inputMembers)

        try buildModelCodingKeys(for: inputMembers)

        if let pagination {
            try buildMakeNextRequestDecl(for: pagination, input: (input, metadata), output: output)
        }
    }
}

@MemberBlockItemListBuilder
func buildModelMemberList(for model: String, usage: APIObject.Usage?, members: [APIObject.Member], documentation: Bool = true, wrappedResponse: Bool = false) -> MemberBlockItemListSyntax {
    for member in members {
        let accessor = wrappedResponse ? AccessorBlockSyntax(accessors: .getter("self.data.\(raw: member.identifier)")) : nil
        let initializer: InitializerClauseSyntax? = {
            guard usage != .out, member.disabled else {
                return nil
            }
            guard let defaultValue = buildDefaultArgument(for: member) else {
                fatalError("Disabled member '\(member.identifier)' must have default value.")
            }
            return .init(value: defaultValue)
        }()

        let binding = PatternBindingSyntax(
            pattern: PatternSyntax("\(raw: member.escapedIdentifier)"),
            typeAnnotation: .init(type: TypeSyntax("\(raw: getSwiftType(for: member))")),
            initializer: initializer,
            accessorBlock: accessor
        )
        DeclSyntax("\(raw: publicLetWithWrapper(for: member, documentation: documentation ? buildDocumentation(summary: member.document) : "", computed: wrappedResponse, deprecated: member.disabled)) \(binding)")
    }
}

func buildResponseModelDecl(for output: String, metadata: APIObject, wrapped: Bool, paginated: Bool) throws -> StructDeclSyntax {
    try StructDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.document))
        public struct \(raw: output): \(raw: paginated ? "TCPaginatedResponse" : "TCResponse")
        """) {

        if wrapped {
            DeclSyntax("private let data: Wrapped")

            try StructDeclSyntax("private struct Wrapped: Codable") {
                buildModelMemberList(for: output, usage: .out, members: metadata.members, documentation: false)
                try buildModelCodingKeys(for: metadata.members)
            }

            buildModelMemberList(for: output, usage: .out, members: metadata.members, wrappedResponse: true)

            DeclSyntax("""
                /// 唯一请求 ID，每次请求都会返回。定位问题时需要提供该次请求的 RequestId。
                public let requestId: String
                """)

            DeclSyntax("""
                enum CodingKeys: String, CodingKey {
                    case data = "Data"
                    case requestId = "RequestId"
                }
                """)
        } else {
            buildModelMemberList(for: output, usage: .out, members: metadata.members)
            try buildModelCodingKeys(for: metadata.members)
        }

        if paginated, let items = getItemsField(for: metadata) {
            buildGetItemsDecl(with: items)

            if let count = getTotalCountField(for: metadata, associative: true) {
                buildGetTotalCountDecl(with: count)
            }
        }
    }
}

func buildGeneralModelDecl(for model: String, metadata: APIObject) throws -> StructDeclSyntax {
    try StructDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.document))
        public struct \(raw: model): \(raw: metadata.protocols.joined(separator: ", "))
        """) {
        let members = metadata.members

        buildModelMemberList(for: model, usage: metadata.usage, members: members)

        if metadata.initializable {
            try buildModelInitializerDecls(for: model, members: members)
        }

        try buildModelCodingKeys(for: members)
    }
}

@MemberBlockItemListBuilder
func buildModelInitializerDecls(for model: String, members: [APIObject.Member]) throws -> MemberBlockItemListSyntax {
    try buildModelInitializerDeclSyntax(for: model, members: members)
    if members.contains(where: \.disabled) {
        try buildModelInitializerDeclSyntax(for: model, members: members, deprecated: true)
    }
}

func buildModelInitializerDeclSyntax(for model: String, members: [APIObject.Member], deprecated: Bool = false) throws -> InitializerDeclSyntax {
    let decl = try InitializerDeclSyntax("public init(\(buildInitializerParameterList(for: members, includeDeprecated: deprecated)))") {
        for member in members where !member.disabled {
            if member.dateType != nil {
                ExprSyntax("""
                    self.\(raw: "_\(member.identifier)") = .init(wrappedValue: \(raw: member.escapedIdentifier))
                    """)
            } else {
                ExprSyntax("self.\(raw: member.memberIdentifier) = \(raw: member.escapedIdentifier)")
            }
        }
    }
    if deprecated, let availability = buildModelMemberDeprecationAttribute(for: members, in: model, functionNameBuilder: { "init(\($0))" }) {
        return decl.with(\.attributes, [.attribute(availability).with(\.trailingTrivia, .newline)])
    } else {
        return decl
    }
}

@MemberBlockItemListBuilder
func buildModelCodingKeys(for members: [APIObject.Member]) throws -> MemberBlockItemListSyntax {
    if !members.isEmpty {
        try EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
            for member in members {
                DeclSyntax("case \(raw: member.escapedIdentifier) = \(literal: member.name)")
            }
        }
    }
}
