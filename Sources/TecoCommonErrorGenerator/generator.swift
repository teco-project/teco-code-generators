import ArgumentParser
import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation
import TecoCodeGeneratorCommons

@main
struct TecoCommonErrorGenerator: ParsableCommand {
    @Option(name: .shortAndLong, completion: .file(extensions: ["swift"]), transform: URL.init(fileURLWithPath:))
    var output: URL

    func run() throws {
        let codes = getErrorCodes()
        let errors = getErrorDefinitions(from: codes)

        let sourceFile = SourceFileSyntax {
            buildCommonErrorStructDecl("TCCommonError", errors: errors)
        }.withCopyrightHeader(generator: Self.self)

        try sourceFile.save(to: self.output)
    }
}
