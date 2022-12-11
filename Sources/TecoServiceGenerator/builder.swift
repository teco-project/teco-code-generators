import SwiftSyntaxBuilder

func buildServiceDecl(with model: APIModel, withErrors hasError: Bool) -> StructDecl {
    StructDecl("""
        \(docComment(summary: model.metadata.serviceName.flatMap { "\($0) (\(model.metadata.shortName))" } ?? model.namespace,
                     discussion: model.metadata.document))
        public struct \(model.namespace): TCService
        """) {

        VariableDecl("""
            /// Client used for communication with Tencent Cloud
            public let client: TCClient
            """)

        VariableDecl("""
            /// Service configuration
            public let config: TCServiceConfig
            """)

        buildServiceInitializerDecl(with: model.metadata, hasError: hasError)
    }
}

func buildServiceInitializerDecl(with serviceMetadata: APIModel.Metadata, hasError: Bool) -> InitializerDecl {
    InitializerDecl("""
        /// Initialize the ``\(raw: serviceMetadata.shortName.upperFirst())`` client
        ///
        /// - Parameters:
        ///    - client: ``TCClient`` used to process requests
        ///    - region: The service region you want to operate on
        ///    - endpoint: Custom Endpoint URL preference
        ///    - timeout: Timeout value for HTTP requests
        public init(
            client: TCClient,
            region: TCRegion? = nil,
            endpoint: TCServiceConfig.EndpointPreference = .global,
            timeout: TimeAmount? = nil,
            byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator()
        ) {
            self.client = client
            self.config = TCServiceConfig(
                region: region,
                service: \(literal: serviceMetadata.shortName),
                apiVersion: \(literal: serviceMetadata.version),
                endpoint: endpoint,\(raw: hasError ? "\nerrorType: TC\(serviceMetadata.shortName.upperFirst())Error.self," : "")
                timeout: timeout,
                byteBufferAllocator: byteBufferAllocator
            )
        }
        """)
}

func buildServicePatchSupportDecl(for qualifiedName: String) -> ExtensionDecl {
    ExtensionDecl("extension \(qualifiedName)") {
        InitializerDecl("""
            /// Initializer required by ``with(region:language:timeout:byteBufferAllocator:)``.
            ///
            /// You are not able to use this initializer directly as there are no public initializers for ``TCServiceConfig/Patch``.
            /// Please use ``with(region:language:timeout:byteBufferAllocator:)`` instead.
            public init(from service: Self, patch: TCServiceConfig.Patch) {
                self.client = service.client
                self.config = service.config.with(patch: patch)
            }
            """)
    }
}
