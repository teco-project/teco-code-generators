import SwiftSyntax
import SwiftSyntaxBuilder

@CodeBlockItemListBuilder
func buildDateHelpersImportDecl(for models: some Collection<APIObject>) -> CodeBlockItemListSyntax {
    if models.flatMap(\.members).contains(where: { $0.dateType != nil }) {
        ImportDeclSyntax("@_exported import struct Foundation.Date")
        ImportDeclSyntax("import TecoDateHelpers")
    }
}

func buildServiceDecl(with model: APIModel, withErrors hasError: Bool) -> StructDeclSyntax {
    StructDeclSyntax("""
        \(docComment(summary: model.metadata.serviceName.flatMap { "\($0) (\(model.metadata.shortName))" } ?? model.namespace,
                     discussion: model.metadata.document))
        public struct \(model.namespace): TCService
        """) {

        VariableDeclSyntax("""
            /// Client used to communicate with Tencent Cloud.
            public let client: TCClient
            """)

        VariableDeclSyntax("""
            /// Service context details.
            public let config: TCServiceConfig
            """)

        buildServiceInitializerDeclSyntax(with: model.metadata, hasError: hasError)
    }
}

func buildServiceInitializerDeclSyntax(with serviceMetadata: APIModel.Metadata, hasError: Bool) -> InitializerDeclSyntax {
    InitializerDeclSyntax("""
        /// Initialize the ``\(raw: serviceMetadata.shortName.upperFirst())`` client.
        ///
        /// - Parameters:
        ///    - client: ``TCClient`` used to perform actions.
        ///    - region: Default region of the service to operate on.
        ///    - language: Preferred language for API response.
        ///    - endpoint: Endpoint provider for API request.
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
                service: \(literal: serviceMetadata.shortName),
                version: \(literal: serviceMetadata.version),
                region: region,
                language: language,
                endpoint: endpoint,
                errorType: \(raw: hasError ? "TC\(serviceMetadata.shortName.upperFirst())Error.self" : "nil"),
                timeout: timeout,
                byteBufferAllocator: byteBufferAllocator
            )
        }
        """)
}

func buildServicePatchSupportDecl(for qualifiedName: String) -> ExtensionDeclSyntax {
    ExtensionDeclSyntax("extension \(qualifiedName)") {
        InitializerDeclSyntax("""
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

func buildModelInitializerDeclSyntax(with members: [APIObject.Member]) -> InitializerDeclSyntax {
    InitializerDeclSyntax("public init(\(initializerParameterList(for: members)))") {
        for member in members {
            if member.dateType != nil {
                SequenceExprSyntax("""
                self.\(raw: "_\(member.identifier)") = .init(wrappedValue: \(raw: member.escapedIdentifier))
                """)
            } else {
                let identifier = member.escapedIdentifier
                SequenceExprSyntax("self.\(raw: identifier) = \(raw: identifier)")
            }
        }
    }
}
