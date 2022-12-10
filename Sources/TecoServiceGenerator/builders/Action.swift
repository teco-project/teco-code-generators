import SwiftSyntaxBuilder

func buildActionDecl(for action: String, metadata: APIModel.Action) -> FunctionDecl {
    FunctionDecl("""
        /// \(raw: metadata.name)
        ///
        \(raw: metadata.document.split(separator: "\n").map { "/// \($0)" }.joined(separator: "\n"))
        @inlinable
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) -> \(raw: "EventLoopFuture<\(metadata.output)>") {
            self.client.execute(action: \(literal: action), serviceConfig: self.config, input: input, logger: logger, on: eventLoop)
        }
        """)
}

func buildAsyncActionDecl(for action: String, metadata: APIModel.Action) -> FunctionDecl {
    FunctionDecl("""
        /// \(raw: metadata.name)
        ///
        \(raw: metadata.document.split(separator: "\n").map { "/// \($0)" }.joined(separator: "\n"))
        @inlinable
        public func \(raw: action.lowerFirst())(_ input: \(raw: metadata.input), logger: Logger = TCClient.loggingDisabled, on eventLoop: EventLoop? = nil) async throws -> \(raw: metadata.output) {
            try await self.client.execute(action: \(literal: action), serviceConfig: self.config, input: input, logger: logger, on: eventLoop).get()
        }
        """)
}
