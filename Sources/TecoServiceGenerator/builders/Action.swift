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
            AttributeSyntax("@discardableResult")
        }
    }
}

private func buildUnavailableBody(for action: String, metadata: APIModel.Action) -> ExprSyntax? {
    metadata.status == .deprecated ? #"fatalError("\#(raw: action) is no longer available.")"# : nil
}

@LabeledExprListBuilder
private func buildInputParameterList(for members: [APIObject.Member]) -> LabeledExprListSyntax {
    for member in members {
        LabeledExprSyntax(label: member.identifier, expression: ExprSyntax("\(raw: member.escapedIdentifier)"))
    }
}

private func buildActionParameterList(for action: APIModel.Action, unpacking input: [APIObject.Member]? = nil, callbackWith output: TypeSyntax? = nil) -> FunctionParameterClauseSyntax {
    FunctionParameterClauseSyntax {
        if let input {
            buildInitializerParameterList(for: input)
        } else {
            FunctionParameterSyntax(firstName: "_", secondName: TokenSyntax("input").spaced(), type: TypeSyntax("\(raw: action.input)"))
        }
        FunctionParameterSyntax(firstName: "region", type: TypeSyntax("TCRegion?"), defaultValue: .init(value: NilLiteralExprSyntax()))
        if let output {
            FunctionParameterSyntax(firstName: "onResponse", type: TypeSyntax("@escaping (\(output), EventLoop) -> EventLoopFuture<Bool>"))
        }
        FunctionParameterSyntax(firstName: "logger", type: TypeSyntax("Logger"), defaultValue: .init(value: ExprSyntax("TCClient.loggingDisabled")))
        FunctionParameterSyntax(firstName: "on", secondName: TokenSyntax("eventLoop").spaced(), type: TypeSyntax("EventLoop?"), defaultValue: .init(value: NilLiteralExprSyntax()))
    }
}

private func buildActionSignatureExpr(for action: APIModel.Action, unpacking input: [APIObject.Member]? = nil, returning output: TypeSyntax? = nil, async: Bool = false, hasCallback: Bool = false) -> FunctionSignatureSyntax {
    precondition(!async || !hasCallback, "We shouldn't mix async/await with callbacks.")
    let output = output ?? "\(raw: action.output)"
    let returnType: TypeSyntax = hasCallback ? "Void" : output
    let parameters = buildActionParameterList(for: action, unpacking: input, callbackWith: hasCallback ? output : nil)
    let effects = async ? FunctionEffectSpecifiersSyntax(asyncSpecifier: .keyword(.async), throwsSpecifier: .keyword(.throws).spaced()) : nil
    return FunctionSignatureSyntax(parameterClause: parameters, effectSpecifiers: effects, returnClause: .init(type: async ? returnType : "EventLoopFuture<\(returnType)>"))
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
    let extraArgs = LabeledExprListSyntax {
        for (label, value) in extraArguments {
            LabeledExprSyntax(label: label, expression: ExprSyntax("\(raw: value)")).with(\.trailingComma, .commaToken())
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
            if let unavailableBody = buildUnavailableBody(for: action, metadata: metadata) {
                unavailableBody
            } else if let input {
                buildUnpackedExecuteExpr(for: action, metadata: metadata, input: input, async: async)
            } else {
                buildExecuteExpr(for: action, metadata: metadata, async: async)
            }
        }
}

func buildPaginatedActionDecl(for action: String, metadata: APIModel.Action, output: APIObject) throws -> FunctionDeclSyntax {
    try FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: false))
        public func \(raw: action.lowerFirst())Paginated\(buildActionSignatureExpr(for: metadata, returning: "(\(raw: output.totalCountType), [\(raw: output.itemType!)])"))
        """) {
        buildUnavailableBody(for: action, metadata: metadata) ?? buildPaginateExpr(for: action)
    }
}

func buildPaginatedActionWithCallbackDecl(for action: String, metadata: APIModel.Action, output: APIObject) throws -> FunctionDeclSyntax {
    try FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: true))
        public func \(raw: action.lowerFirst())Paginated\(buildActionSignatureExpr(for: metadata, hasCallback: true))
        """) {
        buildUnavailableBody(for: action, metadata: metadata) ?? buildPaginateExpr(for: action, extraArguments: [("callback", "onResponse")])
    }
}

func buildActionPaginatorDecl(for action: String, metadata: APIModel.Action, output: APIObject) throws -> FunctionDeclSyntax {
    try FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        ///
        /// - Returns: `AsyncSequence`s of `\(raw: output.itemType!)` and `\(raw: metadata.output)` that can be iterated over asynchronously on demand.
        \(buildActionAttributeList(for: metadata, discardableResult: false))
        public func \(raw: action.lowerFirst())Paginator\(buildActionParameterList(for: metadata)) -> TCClient.PaginatorSequences<\(raw: metadata.input)>
        """) {
        buildUnavailableBody(for: action, metadata: metadata) ??
            "TCClient.Paginator.makeAsyncSequences(input: input, region: region, command: self.\(raw: action.lowerFirst()), logger: logger, on: eventLoop)"
    }
}
