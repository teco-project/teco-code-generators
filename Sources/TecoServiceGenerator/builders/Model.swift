import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

func buildRequestModelDecl(for input: String, metadata: APIObject) -> StructDeclSyntax {
    StructDeclSyntax("""
        \(buildDocumentation(summary: metadata.document))
        public struct \(input): TCRequestModel
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
    }
}

func buildResponseModelDecl(for output: String, metadata: APIObject) -> StructDeclSyntax {
    StructDeclSyntax("""
        \(buildDocumentation(summary: metadata.document))
        public struct \(output): TCResponseModel
        """) {
        let outputMembers = metadata.members

        for member in outputMembers {
            VariableDeclSyntax("""
            \(raw: buildDocumentation(summary: member.document))
            \(raw: publicLetWithWrapper(for: member)) \(raw: member.escapedIdentifier): \(raw: getSwiftType(for: member))
            """)
        }

        buildModelCodingKeys(for: metadata.members)
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
