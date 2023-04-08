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

private func buildActionParameterList(for action: APIModel.Action, unpacking input: [APIObject.Member]? = nil, callback: Bool = false) -> ParameterClauseSyntax {
    ParameterClauseSyntax {
        if let input {
            buildInitializerParameterList(for: input)
        } else {
            FunctionParameterSyntax(firstName: "_", secondName: TokenSyntax("input").spaced(), colon: .colonToken(), type: TypeSyntax("\(raw: action.input)"))
        }
        FunctionParameterSyntax(firstName: "region", colon: .colonToken(), type: TypeSyntax("TCRegion?"), defaultArgument: .init(value: ExprSyntax("nil")))
        if callback {
            FunctionParameterSyntax(firstName: "onResponse", colon: .colonToken(), type: TypeSyntax("@escaping (\(raw: action.output), EventLoop) -> EventLoopFuture<Bool>"))
        }
        FunctionParameterSyntax(firstName: "logger", colon: .colonToken(), type: TypeSyntax("Logger"), defaultArgument: .init(value: ExprSyntax("TCClient.loggingDisabled")))
        FunctionParameterSyntax(firstName: "on", secondName: TokenSyntax("eventLoop").spaced(), colon: .colonToken(), type: TypeSyntax("EventLoop?"), defaultArgument: .init(value: ExprSyntax("nil")))
    }
}

private func buildActionSignatureExpr(for action: APIModel.Action, unpacking input: [APIObject.Member]? = nil, async: Bool, hasCallback: Bool = false) -> FunctionSignatureSyntax {
    precondition(!async || !hasCallback, "We shouldn't mix async/await with callbacks.")
    let parameters = buildActionParameterList(for: action, unpacking: input, callback: hasCallback)
    let effects = async ? DeclEffectSpecifiersSyntax(asyncSpecifier: .keyword(.async).spaced(), throwsSpecifier: .keyword(.throws).spaced()) : nil
    let output: TypeSyntax = hasCallback ? "Void" : "\(raw: action.output)"
    return FunctionSignatureSyntax(input: parameters, effectSpecifiers: effects, output: .init(returnType: async ? output : "EventLoopFuture<\(output)>"))
}

private func buildExecuteExpr(for action: String, metadata: APIModel.Action, async: Bool = false) -> ExprSyntax {
    let executeExpr = ExprSyntax("self.client.execute(action: \(literal: action), region: region, serviceConfig: self.config\(raw: skipAuthorizationParameter(for: action)), input: input, logger: logger, on: eventLoop)")
    return async ? ExprSyntax("try await \(executeExpr).get()") : executeExpr
}

private func buildUnpackedExecuteExpr(for action: String, metadata: APIModel.Action, input: [APIObject.Member], async: Bool = false) -> ExprSyntax {
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

func buildActionDecl(for action: String, metadata: APIModel.Action, unpacking input: [APIObject.Member]? = nil, discardable: Bool, async: Bool = false) throws -> FunctionDeclSyntax {
    try FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardable))
        public func \(raw: action.lowerFirst())\(buildActionSignatureExpr(for: metadata, unpacking: input, async: async))
        """) {
            if metadata.status == .deprecated {
                ExprSyntax(#"fatalError("\#(raw: action) is no longer available.")"#)
            } else if let input {
                buildUnpackedExecuteExpr(for: action, metadata: metadata, input: input, async: async)
            } else {
                buildExecuteExpr(for: action, metadata: metadata, async: async)
            }
        }
}

func buildPaginatedActionDecl(for action: String, metadata: APIModel.Action, output: APIObject) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: false))
        public func \(raw: action.lowerFirst())Paginated\(buildActionParameterList(for: metadata)) -> EventLoopFuture<(\(raw: output.totalCountType), [\(raw: output.itemType!)])> {
            \(buildPaginateExpr(for: action))
        }
        """)
}

func buildPaginatedActionWithCallbackDecl(for action: String, metadata: APIModel.Action, output: APIObject) -> DeclSyntax {
    DeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: true))
        public func \(raw: action.lowerFirst())Paginated\(buildActionSignatureExpr(for: metadata, async: false, hasCallback: true)) {
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
        public func \(raw: action.lowerFirst())Paginator\(buildActionParameterList(for: metadata)) -> TCClient.PaginatorSequences<\(raw: metadata.input)> {
            TCClient.Paginator.makeAsyncSequences(input: input, region: region, command: self.\(raw: action.lowerFirst()), logger: logger, on: eventLoop)
        }
        """)
}

extension SyntaxProtocol {
    fileprivate func spaced() -> Self {
        self.with(\.leadingTrivia, .space)
    }
}
