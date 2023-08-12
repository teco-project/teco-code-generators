import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

private func buildActionAttributeList(for action: APIModel.Action, discardableResult: Bool, additionalAttributes: [AttributeSyntax] = []) -> AttributeListSyntax {
    AttributeListSyntax {
        if let availability = action.availability {
            if let message = action.deprecationMessage {
                AttributeSyntax("@available(*, \(raw: availability), message: \(literal: message))")
                    .with(\.trailingTrivia, .newline)
            } else {
                AttributeSyntax("@available(*, \(raw: availability))").with(\.trailingTrivia, .newline)
            }
        }
        for attribute in additionalAttributes {
            attribute.with(\.trailingTrivia, .newline)
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
private func buildInputParameterList(for members: [APIObject.Member], includeDeprecated: Bool = false) -> LabeledExprListSyntax {
    for member in members where includeDeprecated || !member.disabled {
        LabeledExprSyntax(label: member.identifier, expression: ExprSyntax("\(raw: member.escapedIdentifier)"))
    }
}

private func buildActionParameterList(for action: APIModel.Action, unpacking input: [APIObject.Member]? = nil, includeDeprecated: Bool = false, callbackWith output: TypeSyntax? = nil) -> FunctionParameterClauseSyntax {
    FunctionParameterClauseSyntax {
        if let input {
            buildInitializerParameterList(for: input, includeDeprecated: includeDeprecated)
        } else {
            FunctionParameterSyntax(firstName: "_", secondName: TokenSyntax("input"), type: TypeSyntax("\(raw: action.input)"))
        }
        FunctionParameterSyntax(firstName: "region", type: TypeSyntax("TCRegion?"), defaultValue: .init(value: NilLiteralExprSyntax()))
        if let output {
            FunctionParameterSyntax(firstName: "onResponse", type: TypeSyntax("@escaping (\(output), EventLoop) -> EventLoopFuture<Bool>"))
        }
        FunctionParameterSyntax(firstName: "logger", type: TypeSyntax("Logger"), defaultValue: .init(value: ExprSyntax("TCClient.loggingDisabled")))
        FunctionParameterSyntax(firstName: "on", secondName: TokenSyntax("eventLoop"), type: TypeSyntax("EventLoop?"), defaultValue: .init(value: NilLiteralExprSyntax()))
    }
    .formatted().as(FunctionParameterClauseSyntax.self)!
}

private func buildActionSignatureExpr(for action: APIModel.Action, unpacking input: [APIObject.Member]? = nil, returning output: TypeSyntax? = nil, async: Bool = false, hasCallback: Bool = false, includeDeprecated: Bool = false) -> FunctionSignatureSyntax {
    precondition(!async || !hasCallback, "We shouldn't mix async/await with callbacks.")
    let output = output ?? "\(raw: action.output)"
    let returnType: TypeSyntax = hasCallback ? "Void" : output
    let parameters = buildActionParameterList(for: action, unpacking: input, includeDeprecated: includeDeprecated, callbackWith: hasCallback ? output : nil)
    let effects = async ? FunctionEffectSpecifiersSyntax(asyncSpecifier: .keyword(.async), throwsSpecifier: .keyword(.throws)) : nil
    return FunctionSignatureSyntax(parameterClause: parameters, effectSpecifiers: effects, returnClause: .init(type: async ? returnType : "EventLoopFuture<\(returnType)>"))
        .formatted().as(FunctionSignatureSyntax.self)!
}

private func buildExecuteExpr(for action: String, metadata: APIModel.Action, async: Bool = false) -> ExprSyntax {
    let executeExpr = ExprSyntax("self.client.execute(action: \(literal: action), region: region, serviceConfig: self.config\(raw: skipAuthorizationParameter(for: action)), input: input, logger: logger, on: eventLoop)")
    return async ? ExprSyntax("try await \(executeExpr).get()") : executeExpr
}

private func buildUnpackedExecuteExpr(for action: String, metadata: APIModel.Action, input: [APIObject.Member], deprecated: Bool = false, async: Bool = false) -> ExprSyntax {
    let actionExpr = ExprSyntax("self.\(raw: action.lowerFirst())(.init(\(buildInputParameterList(for: input, includeDeprecated: deprecated))), region: region, logger: logger, on: eventLoop)")
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

private func buildActionDeclSyntax(for action: String, metadata: APIModel.Action, unpacking input: [APIObject.Member]? = nil, discardable: Bool, async: Bool = false, deprecated: Bool = false) throws -> FunctionDeclSyntax {
    let attributes = {
        if deprecated, let input,
           let availability = buildModelMemberDeprecationAttribute(for: input, functionNameBuilder: { "\(action.lowerFirst())(\($0)region:logger:on:)" }) {
            return [availability]
        }
        return []
    }()
    return try FunctionDeclSyntax("""
        \(raw: buildDocumentation(summary: metadata.name, discussion: metadata.document))
        \(buildActionAttributeList(for: metadata, discardableResult: discardable, additionalAttributes: attributes))
        public func \(raw: action.lowerFirst())\(buildActionSignatureExpr(for: metadata, unpacking: input, async: async, includeDeprecated: deprecated))
        """) {
            if let unavailableBody = buildUnavailableBody(for: action, metadata: metadata) {
                unavailableBody
            } else if let input {
                buildUnpackedExecuteExpr(for: action, metadata: metadata, input: input, deprecated: deprecated, async: async)
            } else {
                buildExecuteExpr(for: action, metadata: metadata, async: async)
            }
        }
}

func buildActionDecl(for action: String, metadata: APIModel.Action, discardable: Bool, async: Bool = false) throws -> FunctionDeclSyntax {
    try buildActionDeclSyntax(for: action, metadata: metadata, discardable: discardable, async: async)
}

@MemberBlockItemListBuilder
func buildUnpackedActionDecls(for action: String, metadata: APIModel.Action, unpacking input: [APIObject.Member], discardable: Bool, async: Bool = false) throws -> MemberBlockItemListSyntax {
    try buildActionDeclSyntax(for: action, metadata: metadata, unpacking: input, discardable: discardable, async: async)
    if input.contains(where: \.disabled) {
        try buildActionDeclSyntax(for: action, metadata: metadata, unpacking: input, discardable: discardable, async: async, deprecated: true)
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
        /// - Returns: `AsyncSequence`s of ``\(raw: output.itemType!)`` and ``\(raw: metadata.output)`` that can be iterated over asynchronously on demand.
        \(buildActionAttributeList(for: metadata, discardableResult: false))
        public func \(raw: action.lowerFirst())Paginator\(buildActionParameterList(for: metadata)) -> TCClient.PaginatorSequences<\(raw: metadata.input)>
        """) {
        buildUnavailableBody(for: action, metadata: metadata) ??
            "TCClient.Paginator.makeAsyncSequences(input: input, region: region, command: self.\(raw: action.lowerFirst()), logger: logger, on: eventLoop)"
    }
}
