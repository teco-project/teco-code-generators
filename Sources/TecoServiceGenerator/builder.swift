import SwiftSyntax
import SwiftSyntaxBuilder
import TecoCodeGeneratorCommons

enum ImportContext {
    case client
    case action(input: APIObject, output: APIObject, pagination: Bool)
    case models(any Collection<APIObject>)
    case error
    case exports(any Collection<APIObject>)
}

func buildTecoCoreImportDecls(for context: ImportContext) -> CodeBlockItemListSyntax {
    let date = {
        let members: [APIObject.Member]
        if case .action(let input, let output, _) = context {
            members = input.members + output.members
        } else if case .models(let models) = context {
            members = models.flatMap(\.members)
        } else if case .exports(let models) = context {
            members = models.flatMap(\.members)
        } else {
            return false
        }
        return members.contains(where: { $0.dateType != nil })
    }()

    return CodeBlockItemListSyntax {
        switch context {
        case .exports:
            DeclSyntax("@_exported import TecoCore")
            if date {
                DeclSyntax("@_exported import struct Foundation.Date")
                    .with(\.leadingTrivia, .newlines(2))
            }
        case .error:
            DeclSyntax("import TecoCore")
        case .client:
            DeclSyntax("import NIOCore")
            DeclSyntax("import TecoCore")
        case .models:
            if date {
                DeclSyntax("import struct Foundation.Date")
            }
            DeclSyntax("import TecoCore")
            if date {
                DeclSyntax("import TecoDateHelpers")
            }
        case .action(_, _, let pagination):
            if date {
                DeclSyntax("import struct Foundation.Date")
            }
            DeclSyntax("import Logging")
            DeclSyntax("import NIOCore")
            DeclSyntax("import TecoCore")
            if date {
                DeclSyntax("import TecoDateHelpers")
            }
            if pagination {
                DeclSyntax("import TecoPaginationHelpers")
            }
        }
    }
}

func buildServiceDecl(with model: APIModel, withErrors hasError: Bool) throws -> StructDeclSyntax {
    try StructDeclSyntax("""
        \(raw: buildDocumentation(summary: model.metadata.serviceName.flatMap { "\($0) (\(model.metadata.shortName))" } ?? model.namespace, discussion: model.metadata.document))
        public struct \(raw: model.namespace): TCService
        """) {

        DeclSyntax("""
            /// Client used to communicate with Tencent Cloud.
            public let client: TCClient
            """)

        DeclSyntax("""
            /// Service context details.
            public let config: TCServiceConfig
            """)

        buildServiceInitializerDecl(with: model.metadata, hasError: hasError)
    }
}

func buildServiceInitializerDecl(with serviceMetadata: APIModel.Metadata, hasError: Bool) -> DeclSyntax {
    DeclSyntax("""
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

func buildServicePatchSupportDecl(for service: String) throws -> DeclSyntax {
    try ExtensionDeclSyntax("extension \(raw: service)") {
        DeclSyntax("""
            /// Initializer required by ``with(region:language:endpoint:timeout:byteBufferAllocator:)``.
            ///
            /// You are not able to use this initializer directly as there are no public initializers for ``TCServiceConfig/Patch``.
            /// Please use ``with(region:language:endpoint:timeout:byteBufferAllocator:)`` instead.
            public init(from service: Self, patch: TCServiceConfig.Patch) {
                self.client = service.client
                self.config = service.config.with(patch: patch)
            }
            """)
    }.as(DeclSyntax.self)!
}
