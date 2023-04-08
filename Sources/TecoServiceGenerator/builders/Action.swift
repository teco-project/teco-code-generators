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
            AttributeSyntax("@discardableResult").spaced()
        }
    }
}

@TupleExprElementListBuilder
private func buildInputParameterList(for members: [APIObject.Member]) -> TupleExprElementListSyntax {
    for member in members {
        TupleExprElementSyntax(label: member.identifier, expression: ExprSyntax("\(raw: member.escapedIdentifier)"))
    }
}

private func buildActionSignatureExpr(for action: APIModel.Action, inputs: [APIObject.Member]? = nil, async: Bool) -> FunctionSignatureSyntax {
    let parameters = ParameterClauseSyntax {
        if let inputs {
            buildInitializerParameterList(for: inputs)
        } else {
            FunctionParameterSyntax(firstName: "_", secondName: TokenSyntax("input").spaced(), colon: .colonToken(), type: TypeSyntax("\(raw: action.input)"))
        }
        FunctionParameterSyntax(firstName: "region", colon: .colonToken(), type: TypeSyntax("TCRegion?"), defaultArgument: .init(value: ExprSyntax("nil")))
        FunctionParameterSyntax(firstName: "logger", colon: .colonToken(), type: TypeSyntax("Logger"), defaultArgument: .init(value: ExprSyntax("TCClient.loggingDisabled")))
        FunctionParameterSyntax(firstName: "on", secondName: TokenSyntax("eventLoop").spaced(), colon: .colonToken(), type: TypeSyntax("EventLoop?"), defaultArgument: .init(value: ExprSyntax("nil")))
    }
    let effects = async ? DeclEffectSpecifiersSyntax(asyncSpecifier: .keyword(.async).spaced(), throwsSpecifier: .keyword(.throws).spaced()) : nil
    let output: TypeSyntax = async ? "\(raw: action.output)" : "EventLoopFuture<\(raw: action.output)>"
    return FunctionSignatureSyntax(input: parameters, effectSpecifiers: effects, output: .init(returnType: output))
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

func buildActionDecl(for action: String, metadata: APIModel.Action, discardableResult: Bool, async: Bool = false) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())\(buildActionSignatureExpr(for: metadata, async: async)) {
            \(buildExecuteExpr(for: action, metadata: metadata, async: async))
        }
        """)
}

func buildUnpackedActionDecl(for action: String, metadata: APIModel.Action, inputMembers: [APIObject.Member], discardableResult: Bool, async: Bool = false) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardableResult))
        public func \(raw: action.lowerFirst())\(buildActionSignatureExpr(for: metadata, inputs: inputMembers, async: async)) {
            \(buildUnpackedExecuteExpr(for: action, metadata: metadata, input: inputMembers, async: async))
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

extension SyntaxProtocol {
    fileprivate func spaced() -> Self {
        self.with(\.leadingTrivia, .space)
    }
}
