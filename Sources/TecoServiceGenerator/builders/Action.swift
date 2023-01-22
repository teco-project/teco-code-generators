import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

private func buildActionAttributeList(discardableResult: Bool) -> AttributeListSyntax {
    AttributeListSyntax {
        AttributeSyntax("@inlinable")
        if discardableResult {
            AttributeSyntax("@discardableResult").withLeadingTrivia(.space)
        }
    }
}

func buildActionDecl(for action: String, metadata: APIModel.Action, discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> \(raw: "EventLoopFuture<\(metadata.output)>") {
            self.client.execute(action: \(literal: action), region: region, serviceConfig: self.config\(raw: skipAuthorizationParameter(for: action)), input: input, logger: logger, on: eventLoop)
        }
        """)
}

func buildAsyncActionDecl(for action: String, metadata: APIModel.Action, discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) async throws -> \(raw: metadata.output) {
            try await self.client.execute(action: \(literal: action), region: region, serviceConfig: self.config\(raw: skipAuthorizationParameter(for: action)), input: input, logger: logger, on: eventLoop).get()
        }
        """)
}

func buildUnpackedActionDecl(for action: String, metadata: APIModel.Action, inputMembers: [APIObject.Member], discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(\(raw: initializerParameterList(for: inputMembers, packed: true))region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> \(raw: "EventLoopFuture<\(metadata.output)>") {
            self.\(raw: action.lowerFirst())(\(raw: metadata.input)(\(raw: inputMembers.map({ "\($0.identifier): \($0.escapedIdentifier)" }).joined(separator: ", "))), region: region, logger: logger, on: eventLoop)
        }
        """)
}

func buildUnpackedAsyncActionDecl(for action: String, metadata: APIModel.Action, inputMembers: [APIObject.Member], discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(\(raw: initializerParameterList(for: inputMembers, packed: true))region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) async throws -> \(raw: metadata.output) {
            try await self.\(raw: action.lowerFirst())(\(raw: metadata.input)(\(raw: inputMembers.map({ "\($0.identifier): \($0.escapedIdentifier)" }).joined(separator: ", "))), region: region, logger: logger, on: eventLoop)
        }
        """)
}
