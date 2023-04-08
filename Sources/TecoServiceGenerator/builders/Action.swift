import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

private func buildActionAttributeList(for action: APIModel.Action, discardableResult: Bool) -> AttributeListSyntax {
    AttributeListSyntax {
        if let availability = action.availability {
            if let message = action.deprecationMessage {
                AttributeSyntax("@available(*, \(raw: availability), message: \(literal: message))")
                    .with(\.trailingTrivia, .newline)
            } else {
                AttributeSyntax("@available(*, \(raw: availability))").with(\.trailingTrivia, .newline)
            }
        }
        AttributeSyntax("@inlinable")
        if discardableResult {
            AttributeSyntax("@discardableResult").with(\.leadingTrivia, .space)
        }
    }
}

@TupleExprElementListBuilder
private func buildInputParameterList(for members: [APIObject.Member]) -> TupleExprElementListSyntax {
    for member in members {
        TupleExprElementSyntax(label: member.identifier, expression: ExprSyntax("\(raw: member.escapedIdentifier)"))
    }
}

private func buildExecuteExpr(for action: String, metadata: APIModel.Action, async: Bool = false) -> ExprSyntax {
    guard metadata.status != .deprecated else {
        return ExprSyntax(#"fatalError("\#(raw: action) is no longer available.")"#)
    }
    let executeExpr = ExprSyntax("self.client.execute(action: \(literal: action), region: region, serviceConfig: self.config\(raw: skipAuthorizationParameter(for: action)), input: input, logger: logger, on: eventLoop)")
    return async ? ExprSyntax("try await \(executeExpr).get()") : executeExpr
}

private func buildUnpackedExecuteExpr(for action: String, metadata: APIModel.Action, input: [APIObject.Member], async: Bool = false) -> ExprSyntax {
    guard metadata.status != .deprecated else {
        return ExprSyntax(#"fatalError("\#(raw: action) is no longer available.")"#)
    }
    let actionExpr = ExprSyntax("self.\(raw: action.lowerFirst())(.init(\(buildInputParameterList(for: input))), region: region, logger: logger, on: eventLoop)")
    return async ? ExprSyntax("try await \(actionExpr)") : actionExpr
}

private func buildPaginateExpr(for action: String, extraArguments: [(String, String)] = []) -> ExprSyntax {
    let extraArgs = TupleExprElementListSyntax {
        for (label, value) in extraArguments {
            TupleExprElementSyntax(label: .identifier(label), colon: .colonToken(), expression: ExprSyntax("\(raw: value)"), trailingComma: .commaToken())
        }
    }
    return ExprSyntax("self.client.paginate(input: input, region: region, command: self.\(raw: action.lowerFirst()), \(extraArgs)logger: logger, on: eventLoop)")
}

func buildActionDecl(for action: String, metadata: APIModel.Action, discardableResult: Bool) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> \(raw: "EventLoopFuture<\(metadata.output)>") {
            \(buildExecuteExpr(for: action, metadata: metadata))
        }
        """)
}

func buildAsyncActionDecl(for action: String, metadata: APIModel.Action, discardableResult: Bool) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) async throws -> \(raw: metadata.output) {
            \(buildExecuteExpr(for: action, metadata: metadata, async: true))
        }
        """)
}

func buildUnpackedActionDecl(for action: String, metadata: APIModel.Action, inputMembers: [APIObject.Member], discardableResult: Bool) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(\(buildInitializerParameterList(for: inputMembers, packed: true))region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> \(raw: "EventLoopFuture<\(metadata.output)>") {
            \(buildUnpackedExecuteExpr(for: action, metadata: metadata, input: inputMembers))
        }
        """)
}

func buildUnpackedAsyncActionDecl(for action: String, metadata: APIModel.Action, inputMembers: [APIObject.Member], discardableResult: Bool) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())(\(buildInitializerParameterList(for: inputMembers, packed: true))region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) async throws -> \(raw: metadata.output) {
            \(buildUnpackedExecuteExpr(for: action, metadata: metadata, input: inputMembers, async: true))
        }
        """)
}

func buildPaginatedActionDecl(for action: String, metadata: APIModel.Action, output: APIObject) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: false))
        public func \(raw: action.lowerFirst())Paginated(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> EventLoopFuture<(\(raw: output.totalCountType), [\(raw: output.itemType!)])> {
            \(buildPaginateExpr(for: action))
        }
        """)
}

func buildPaginatedActionWithCallbackDecl(for action: String, metadata: APIModel.Action, output: APIObject) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: true))
        public func \(raw: action.lowerFirst())Paginated(_ input: \(raw: metadata.input), region: TCRegion? = nil, onResponse: @escaping (\(raw: metadata.output), EventLoop) -> EventLoopFuture<Bool>, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> EventLoopFuture<Void> {
            \(buildPaginateExpr(for: action, extraArguments: [("callback", "onResponse")]))
        }
        """)
}

func buildActionPaginatorDecl(for action: String, metadata: APIModel.Action, output: APIObject) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        ///
        /// - Returns: `AsyncSequence`s of `\(raw: output.itemType!)` and `\(raw: metadata.output)` that can be iterated over asynchronously on demand.
        \(buildActionAttributeList(for: metadata, discardableResult: false))
        public func \(raw: action.lowerFirst())Paginator(_ input: \(raw: metadata.input), region: TCRegion? = nil, logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> TCClient.PaginatorSequences<\(raw: metadata.input)> {
            TCClient.Paginator.makeAsyncSequences(input: input, region: region, command: self.\(raw: action.lowerFirst()), logger: logger, on: eventLoop)
        }
        """)
}
