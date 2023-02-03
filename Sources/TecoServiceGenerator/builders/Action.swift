import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

private func buildActionAttributeList(for action: APIModel.Action, discardableResult: Bool) -> AttributeListSyntax {
    AttributeListSyntax {
        if let availability = action.availability {
            if let message = action.deprecationMessage {
                AttributeSyntax("@available(*, \(raw: availability), message: \(literal: message))")
                    .withTrailingTrivia(.newline)
            } else {
                AttributeSyntax("@available(*, \(raw: availability))").withTrailingTrivia(.newline)
            }
        }
        AttributeSyntax("@inlinable")
        if discardableResult {
            AttributeSyntax("@discardableResult").withLeadingTrivia(.space)
        }
    }
}

private func buildExecuteExpr(for action: String) -> ExprSyntax {
    ExprSyntax("self.client.execute(action: \(literal: action), region: region, serviceConfig: self.config\(raw: skipAuthorizationParameter(for: action)), input: input, logger: logger, on: eventLoop)")
}

private func buildInputExpr(for type: String, members: [APIObject.Member]) -> FunctionCallExprSyntax {
    let parameters = members.map({ "\($0.identifier): \($0.escapedIdentifier)" }).joined(separator: ", ")
    return FunctionCallExprSyntax("\(raw: type)(\(raw: parameters))")
}

func buildActionDecl(for action: String, metadata: APIModel.Action, discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> \(raw: "EventLoopFuture<\(metadata.output)>") {
            \(buildExecuteExpr(for: action))
        }
        """)
}

func buildAsyncActionDecl(for action: String, metadata: APIModel.Action, discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) async throws -> \(raw: metadata.output) {
            try await \(buildExecuteExpr(for: action)).get()
        }
        """)
}

func buildUnpackedActionDecl(for action: String, metadata: APIModel.Action, inputMembers: [APIObject.Member], discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(\(raw: initializerParameterList(for: inputMembers, packed: true))region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> \(raw: "EventLoopFuture<\(metadata.output)>") {
            let input = \(buildInputExpr(for: metadata.input, members: inputMembers))
            return \(buildExecuteExpr(for: action))
        }
        """)
}

func buildUnpackedAsyncActionDecl(for action: String, metadata: APIModel.Action, inputMembers: [APIObject.Member], discardableResult: Bool) -> FunctionDeclSyntax {
    FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(\(raw: initializerParameterList(for: inputMembers, packed: true))region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) async throws -> \(raw: metadata.output) {
            let input = \(buildInputExpr(for: metadata.input, members: inputMembers))
            return try await \(buildExecuteExpr(for: action)).get()
        }
        """)
}
