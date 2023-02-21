import ArgumentParser
import class Foundation.FileManager
@_exported import struct Foundation.URL

struct Context {
    @TaskLocal
    static var dryRun: Bool = false
}

public protocol TecoCodeGenerator: AsyncParsableCommand {
    var dryRun: Bool { get }

    func generate() async throws
}

extension TecoCodeGenerator {
    public func run() async throws {
        try await Context.$dryRun.withValue(dryRun, operation: generate)
    }
}
