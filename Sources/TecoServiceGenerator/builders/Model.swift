import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

func buildRequestModelDecl(for input: String, metadata: APIObject, paginationKind: PaginationKind?, output: String, outputMetadata: APIObject) -> StructDeclSyntax {
    StructDeclSyntax("""
        \(buildDocumentation(summary: metadata.document))
        public struct \(input): \(paginationKind != nil ? "TCPaginatedRequest" : "TCRequestModel")
        """) {
        let inputMembers = metadata.members.filter({ $0.type != .binary })

        for member in inputMembers {
            VariableDeclSyntax("""
                \(raw: buildDocumentation(summary: member.document))
                \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                """)
        }

        buildModelInitializerDeclSyntax(with: inputMembers)

        buildModelCodingKeys(for: inputMembers)

        if let paginationKind {
            buildGetNextPaginatedRequestDecl(for: input, response: output, kind: paginationKind, input: metadata, output: outputMetadata)
        }
    }
}

func buildResponseModelDecl(for output: String, metadata: APIObject, paginated: Bool) -> StructDeclSyntax {
    StructDeclSyntax("""
        \(buildDocumentation(summary: metadata.document))
        public struct \(output): \(paginated ? "TCPaginatedResponse" : "TCResponseModel")
        """) {
        let outputMembers = metadata.members

        for member in outputMembers {
            VariableDeclSyntax("""
            \(raw: buildDocumentation(summary: member.document))
            \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
            """)
        }

        buildModelCodingKeys(for: metadata.members)

        if paginated, let itemsField = getItemsField(for: metadata) {
            buildGetItemsDecl(with: itemsField)

            if let field = getTotalCountField(for: metadata, associative: true) {
                buildGetTotalCountDecl(with: field)
            }
        }
    }
}

func buildGeneralModelDecl(for model: String, metadata: APIObject) -> StructDeclSyntax {
    StructDeclSyntax("""
        \(buildDocumentation(summary: metadata.document))
        public struct \(model): \(metadata.protocols.joined(separator: ", "))
        """) {
        let members = metadata.members

        for member in members {
            VariableDeclSyntax("""
                \(raw: buildDocumentation(summary: member.document))
                \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
                """)
        }

        if metadata.initializable {
            buildModelInitializerDeclSyntax(with: members)
        }

        buildModelCodingKeys(for: members)
    }
}

func buildModelInitializerDeclSyntax(with members: [APIObject.Member]) -> InitializerDeclSyntax {
    InitializerDeclSyntax("public init(\(initializerParameterList(for: members)))") {
        for member in members {
            if member.dateType != nil {
                SequenceExprSyntax("""
                self.\(raw: "_\(member.identifier)") = .init(wrappedValue: \(raw: member.escapedIdentifier))
                """)
            } else {
                SequenceExprSyntax("self.\(raw: member.identifier) = \(raw: member.escapedIdentifier)")
            }
        }
    }
}

@MemberDeclListBuilder
func buildModelCodingKeys(for members: [APIObject.Member]) -> MemberDeclListSyntax {
    if !members.isEmpty {
        EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
            for member in members {
                EnumCaseDeclSyntax("case \(raw: member.escapedIdentifier) = \(literal: member.name)")
            }
        }
    }
}
