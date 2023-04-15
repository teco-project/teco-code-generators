import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

func buildInitializerParameterList(for members: [APIObject.Member]) -> FunctionParameterListSyntax {
    func getDefaultArgument(for member: APIObject.Member) -> ExprSyntax? {
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
        if !member.required {
            return NilLiteralExprSyntax().as(ExprSyntax.self)
        }
        return nil
    }

    return FunctionParameterListSyntax {
        for member in members {
            FunctionParameterSyntax(
                firstName: "\(raw: member.identifier)",
                colon: .colonToken(),
                type: TypeSyntax("\(raw: getSwiftType(for: member, isInitializer: true))"),
                defaultArgument: getDefaultArgument(for: member).map { .init(value: $0) }
            )
        }
    }
}

func buildRequestModelDecl(for input: String, metadata: APIObject, pagination: Pagination?, output: (name: String, metadata: APIObject)) throws -> StructDeclSyntax {
    try StructDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.document))
        public struct \(raw: input): \(raw: pagination != nil ? "TCPaginatedRequest" : "TCRequestModel")
        """) {
        let inputMembers = metadata.members.filter({ $0.type != .binary })

        for member in inputMembers {
            DeclSyntax("""
                \(raw: buildDocumentation(summary: member.document))
                \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                """)
        }

        try buildModelInitializerDeclSyntax(with: inputMembers)

        try buildModelCodingKeys(for: inputMembers)

        if let pagination {
            try buildMakeNextRequestDecl(for: pagination, input: (input, metadata), output: output)
        }
    }
}

func buildResponseModelDecl(for output: String, metadata: APIObject, paginated: Bool) throws -> StructDeclSyntax {
    try StructDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.document))
        public struct \(raw: output): \(raw: paginated ? "TCPaginatedResponse" : "TCResponseModel")
        """) {
        let outputMembers = metadata.members

        for member in outputMembers {
            DeclSyntax("""
                \(raw: buildDocumentation(summary: member.document))
                \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                """)
        }

        try buildModelCodingKeys(for: metadata.members)

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

        for member in members {
            DeclSyntax("""
                \(raw: buildDocumentation(summary: member.document))
                \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                """)
        }

        if metadata.initializable {
            try buildModelInitializerDeclSyntax(with: members)
        }

        try buildModelCodingKeys(for: members)
    }
}

func buildModelInitializerDeclSyntax(with members: [APIObject.Member]) throws -> InitializerDeclSyntax {
    try InitializerDeclSyntax("public init(\(buildInitializerParameterList(for: members)))") {
        for member in members {
            if member.dateType != nil {
                ExprSyntax("""
                    self.\(raw: "_\(member.identifier)") = .init(wrappedValue: \(raw: member.escapedIdentifier))
                    """)
            } else {
                ExprSyntax("self.\(raw: member.identifier) = \(raw: member.escapedIdentifier)")
            }
        }
    }
}

@MemberDeclListBuilder
func buildModelCodingKeys(for members: [APIObject.Member]) throws -> MemberDeclListSyntax {
    if !members.isEmpty {
        try EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
            for member in members {
                DeclSyntax("case \(raw: member.escapedIdentifier) = \(literal: member.name)")
            }
        }
    }
}
