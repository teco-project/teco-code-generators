import SwiftSyntaxBuilder

@CodeBlockItemListBuilder
func buildDateHelpersImportDecl(for models: some Collection<APIObject>) -> CodeBlockItemList {
    if models.flatMap(\.members).contains(where: { $0.dateType != nil }) {
        ImportDecl("@_exported import struct Foundation.Date")
        ImportDecl("import TecoDateHelpers")
    }
}

func buildServiceDecl(with model: APIModel, withErrors hasError: Bool) -> StructDecl {
    StructDecl("""
        \(docComment(summary: model.metadata.serviceName.flatMap { "\($0) (\(model.metadata.shortName))" } ?? model.namespace,
                     discussion: model.metadata.document))
        public struct \(model.namespace): TCService
        """) {

        VariableDecl("""
            /// Client used to communicate with Tencent Cloud.
            public let client: TCClient
            """)

        VariableDecl("""
            /// Service context details.
            public let config: TCServiceConfig
            """)

        buildServiceInitializerDecl(with: model.metadata, hasError: hasError)
    }
}

func buildServiceInitializerDecl(with serviceMetadata: APIModel.Metadata, hasError: Bool) -> InitializerDecl {
    InitializerDecl("""
        /// Initialize the ``\(raw: serviceMetadata.shortName.upperFirst())`` client.
        ///
        /// - Parameters:
        ///    - client: ``TCClient`` used to perform actions.
        ///    - region: Region of the service you want to operate on.
        ///    - language: Preferred language for API response.
        ///    - endpoint: Custom endpoint URL for API request.
        ///    - timeout: Timeout value for HTTP requests.
        public init(
            client: TCClient,
            region: TCRegion? = nil,
            language: TCServiceConfig.Language? = nil,
            endpoint: TCServiceConfig.Endpoint = .global,
            timeout: TimeAmount? = nil,
            byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()
        ) {
            self.client = client
            self.config = TCServiceConfig(
                region: region,
                service: \(literal: serviceMetadata.shortName),
                apiVersion: \(literal: serviceMetadata.version),
                language: language,
                endpoint: endpoint,
                errorType: \(raw: hasError ? "TC\(serviceMetadata.shortName.upperFirst())Error.self" : "nil"),
                timeout: timeout,
                byteBufferAllocator: byteBufferAllocator
            )
        }
        """)
}

func buildServicePatchSupportDecl(for qualifiedName: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedName)") {
        InitializerDecl("""
            /// Initializer required by ``with(region:language:endpoint:timeout:byteBufferAllocator:)``.
            ///
            /// You are not able to use this initializer directly as there are no public initializers for ``TCServiceConfig/Patch``.
            /// Please use ``with(region:language:endpoint:timeout:byteBufferAllocator:)`` instead.
            public init(from service: Self, patch: TCServiceConfig.Patch) {
                self.client = service.client
                self.config = service.config.with(patch: patch)
            }
            """)
    }
}

func buildModelInitializerDecl(with members: [APIObject.Member]) -> InitializerDecl {
    InitializerDecl("public init(\(initializerParameterList(for: members)))") {
        for member in members {
            if member.dateType != nil {
                SequenceExpr("""
                self.\(raw: "_\(member.identifier)") = .init(wrappedValue: \(raw: member.escapedIdentifier))
                """)
            } else {
                let identifier = member.escapedIdentifier
                SequenceExpr("self.\(raw: identifier) = \(raw: identifier)")
            }
        }
    }
}
